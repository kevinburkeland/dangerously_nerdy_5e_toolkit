import '../magic_item_data.dart';

/// Complete catalog of canonical SRD 5.1 / 5.2 nonmagical adventuring gear, equipment, and tools.
class SrdAdventuringGear {
  static const List<EquipmentItem> items = [
    // =========================================================================
    // 1. CONTAINERS & STORAGE
    // =========================================================================
    EquipmentItem(
      id: EntityId(slug: 'backpack', ruleset: RulesetVersion.v2024), name: 'Backpack',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Holds 1 cubic foot or 30 pounds of gear. You can strap items like a bedroll or rope to the outside.',
      rules2014: ItemEditionDetails(
        summary:
            'Holds 1 cubic foot or 30 pounds of gear. You can strap items like a bedroll or rope to the outside.',
        description:
            'A standard leather or canvas backpack designed for carrying adventuring supplies across dungeons and wilderness.',
        properties: [
          'Capacity: 1 cubic foot / 30 pounds.',
          'Weight: 5 lbs.',
          'Cost: 2 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Holds 1 cubic foot or 30 pounds of gear. You can strap items like a bedroll or rope to the outside.',
        description:
            'A standard leather or canvas backpack designed for carrying adventuring supplies across dungeons and wilderness.',
        properties: [
          'Capacity: 1 cubic foot / 30 pounds.',
          'Weight: 5 lbs.',
          'Cost: 2 gp.',
        ],
      ),
      tags: ['gear', 'container', 'storage', 'equipment'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'container', 'storage', 'equipment'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'barrel', ruleset: RulesetVersion.v2024), name: 'Barrel',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Holds 40 gallons of liquid or 4 cubic feet of solid cargo.',
      rules2014: ItemEditionDetails(
        summary: 'Holds 40 gallons of liquid or 4 cubic feet of solid cargo.',
        description:
            'A sturdy wooden cask bound with iron hoops, used for transporting ale, water, oil, and foodstuffs.',
        properties: [
          'Capacity: 40 gallons liquid / 4 cubic feet solid.',
          'Weight: 70 lbs.',
          'Cost: 2 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Holds 40 gallons of liquid or 4 cubic feet of solid cargo.',
        description:
            'A sturdy wooden cask bound with iron hoops, used for transporting ale, water, oil, and foodstuffs.',
        properties: [
          'Capacity: 40 gallons liquid / 4 cubic feet solid.',
          'Weight: 70 lbs.',
          'Cost: 2 gp.',
        ],
      ),
      tags: ['gear', 'container', 'storage', 'liquid'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'container', 'storage', 'liquid'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'basket', ruleset: RulesetVersion.v2024), name: 'Basket',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Holds 2 cubic feet or 40 pounds of gear.',
      rules2014: ItemEditionDetails(
        summary: 'Holds 2 cubic feet or 40 pounds of gear.',
        description:
            'A woven wicker or reed basket with sturdy handles for foraging and marketplace provisioning.',
        properties: [
          'Capacity: 2 cubic feet / 40 pounds.',
          'Weight: 2 lbs.',
          'Cost: 4 sp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Holds 2 cubic feet or 40 pounds of gear.',
        description:
            'A woven wicker or reed basket with sturdy handles for foraging and marketplace provisioning.',
        properties: [
          'Capacity: 2 cubic feet / 40 pounds.',
          'Weight: 2 lbs.',
          'Cost: 4 sp.',
        ],
      ),
      tags: ['gear', 'container', 'storage'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'container', 'storage'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'bottle_glass', ruleset: RulesetVersion.v2024), name: 'Bottle, Glass',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Holds 1½ pints of liquid, corked with wax-sealed stopper.',
      rules2014: ItemEditionDetails(
        summary: 'Holds 1½ pints of liquid, corked with wax-sealed stopper.',
        description:
            'A thick glass bottle suitable for storing wine, potions, distilled essences, or holy reagents.',
        properties: [
          'Capacity: 1½ pints liquid.',
          'Weight: 2 lbs.',
          'Cost: 2 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Holds 1½ pints of liquid, corked with wax-sealed stopper.',
        description:
            'A thick glass bottle suitable for storing wine, potions, distilled essences, or holy reagents.',
        properties: [
          'Capacity: 1½ pints liquid.',
          'Weight: 2 lbs.',
          'Cost: 2 gp.',
        ],
      ),
      tags: ['gear', 'container', 'liquid'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'container', 'liquid'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'bucket', ruleset: RulesetVersion.v2024), name: 'Bucket',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Holds 3 gallons of liquid or ½ cubic foot of solid matter.',
      rules2014: ItemEditionDetails(
        summary: 'Holds 3 gallons of liquid or ½ cubic foot of solid matter.',
        description:
            'A wooden pail with a rope or metal bail handle for drawing water and clearing bilges.',
        properties: [
          'Capacity: 3 gallons liquid / ½ cubic foot.',
          'Weight: 2 lbs.',
          'Cost: 5 cp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Holds 3 gallons of liquid or ½ cubic foot of solid matter.',
        description:
            'A wooden pail with a rope or metal bail handle for drawing water and clearing bilges.',
        properties: [
          'Capacity: 3 gallons liquid / ½ cubic foot.',
          'Weight: 2 lbs.',
          'Cost: 5 cp.',
        ],
      ),
      tags: ['gear', 'container', 'liquid', 'utility'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'container', 'liquid', 'utility'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'case_crossbow_bolt', ruleset: RulesetVersion.v2024), name: 'Case, Crossbow Bolt',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Holds up to 20 crossbow bolts securely in a rigid leather container.',
      rules2014: ItemEditionDetails(
        summary:
            'Holds up to 20 crossbow bolts securely in a rigid leather container.',
        description:
            'A hard-molded leather cylindrical case with a snug cap to protect bolts from moisture and damage.',
        properties: [
          'Capacity: 20 bolts.',
          'Weight: 1 lb.',
          'Cost: 1 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Holds up to 20 crossbow bolts securely in a rigid leather container.',
        description:
            'A hard-molded leather cylindrical case with a snug cap to protect bolts from moisture and damage.',
        properties: [
          'Capacity: 20 bolts.',
          'Weight: 1 lb.',
          'Cost: 1 gp.',
        ],
      ),
      tags: ['gear', 'container', 'ammunition'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'container', 'ammunition'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'case_map_scroll', ruleset: RulesetVersion.v2024), name: 'Case, Map or Scroll',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Holds up to 10 rolled-up sheets of paper or 5 rolled-up sheets of parchment.',
      rules2014: ItemEditionDetails(
        summary:
            'Holds up to 10 rolled-up sheets of paper or 5 rolled-up sheets of parchment.',
        description:
            'A watertight cylindrical leather or wooden tube with a screw cap for safeguarding documents.',
        properties: [
          'Capacity: 10 rolled paper or 5 parchment sheets.',
          'Weight: 1 lb.',
          'Cost: 1 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Holds up to 10 rolled-up sheets of paper or 5 rolled-up sheets of parchment.',
        description:
            'A watertight cylindrical leather or wooden tube with a screw cap for safeguarding documents.',
        properties: [
          'Capacity: 10 rolled paper or 5 parchment sheets.',
          'Weight: 1 lb.',
          'Cost: 1 gp.',
        ],
      ),
      tags: ['gear', 'container', 'scrolls', 'maps'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'container', 'scrolls', 'maps'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'chest', ruleset: RulesetVersion.v2024), name: 'Chest',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Holds 12 cubic feet or 300 pounds of gear. Reinforced with iron bands.',
      rules2014: ItemEditionDetails(
        summary:
            'Holds 12 cubic feet or 300 pounds of gear. Reinforced with iron bands.',
        description:
            'A heavy wooden chest with iron corners, hasp, and side handles for secure dungeon and camp storage.',
        properties: [
          'Capacity: 12 cubic feet / 300 pounds.',
          'Weight: 25 lbs.',
          'Cost: 5 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Holds 12 cubic feet or 300 pounds of gear. Reinforced with iron bands.',
        description:
            'A heavy wooden chest with iron corners, hasp, and side handles for secure dungeon and camp storage.',
        properties: [
          'Capacity: 12 cubic feet / 300 pounds.',
          'Weight: 25 lbs.',
          'Cost: 5 gp.',
        ],
      ),
      tags: ['gear', 'container', 'storage', 'heavy'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'container', 'storage', 'heavy'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'flask_tankard', ruleset: RulesetVersion.v2024), name: 'Flask or Tankard',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Holds 1 pint of liquid.',
      rules2014: ItemEditionDetails(
        summary: 'Holds 1 pint of liquid.',
        description:
            'A pewter, leather, or ceramic vessel for tavern drinking or pocket carriage of spirits.',
        properties: [
          'Capacity: 1 pint liquid.',
          'Weight: 1 lb.',
          'Cost: 2 cp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Holds 1 pint of liquid.',
        description:
            'A pewter, leather, or ceramic vessel for tavern drinking or pocket carriage of spirits.',
        properties: [
          'Capacity: 1 pint liquid.',
          'Weight: 1 lb.',
          'Cost: 2 cp.',
        ],
      ),
      tags: ['gear', 'container', 'liquid'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'container', 'liquid'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'jug_pitcher', ruleset: RulesetVersion.v2024), name: 'Jug or Pitcher',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Holds 1 gallon of liquid.',
      rules2014: ItemEditionDetails(
        summary: 'Holds 1 gallon of liquid.',
        description:
            'A ceramic or earthen jug with a narrow neck and handle for serving water, wine, or oil.',
        properties: [
          'Capacity: 1 gallon liquid.',
          'Weight: 4 lbs.',
          'Cost: 2 cp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Holds 1 gallon of liquid.',
        description:
            'A ceramic or earthen jug with a narrow neck and handle for serving water, wine, or oil.',
        properties: [
          'Capacity: 1 gallon liquid.',
          'Weight: 4 lbs.',
          'Cost: 2 cp.',
        ],
      ),
      tags: ['gear', 'container', 'liquid'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'container', 'liquid'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'pot_iron', ruleset: RulesetVersion.v2024), name: 'Pot, Iron',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Holds 1 gallon of liquid for campfire cooking and boiling water.',
      rules2014: ItemEditionDetails(
        summary:
            'Holds 1 gallon of liquid for campfire cooking and boiling water.',
        description:
            'A heavy cast-iron cooking vessel with a lid and hanging handle.',
        properties: [
          'Capacity: 1 gallon.',
          'Weight: 10 lbs.',
          'Cost: 2 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Holds 1 gallon of liquid for campfire cooking and boiling water.',
        description:
            'A heavy cast-iron cooking vessel with a lid and hanging handle.',
        properties: [
          'Capacity: 1 gallon.',
          'Weight: 10 lbs.',
          'Cost: 2 gp.',
        ],
      ),
      tags: ['gear', 'container', 'cooking', 'utility'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'container', 'cooking', 'utility'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'pouch', ruleset: RulesetVersion.v2024), name: 'Pouch',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Holds ⅕ cubic foot or up to 6 pounds of small items or coins (approx. 300 coins).',
      rules2014: ItemEditionDetails(
        summary:
            'Holds ⅕ cubic foot or up to 6 pounds of small items or coins (approx. 300 coins).',
        description:
            'A cloth or leather pouch that fastens with a drawstring and secures to a belt.',
        properties: [
          'Capacity: ⅕ cubic foot / 6 lbs / 300 coins.',
          'Weight: 1 lb.',
          'Cost: 5 sp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Holds ⅕ cubic foot or up to 6 pounds of small items or coins (approx. 300 coins).',
        description:
            'A cloth or leather pouch that fastens with a drawstring and secures to a belt.',
        properties: [
          'Capacity: ⅕ cubic foot / 6 lbs / 300 coins.',
          'Weight: 1 lb.',
          'Cost: 5 sp.',
        ],
      ),
      tags: ['gear', 'container', 'storage', 'coins'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'container', 'storage', 'coins'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'quiver', ruleset: RulesetVersion.v2024), name: 'Quiver',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Holds up to 20 arrows comfortably over the shoulder or on the hip.',
      rules2014: ItemEditionDetails(
        summary:
            'Holds up to 20 arrows comfortably over the shoulder or on the hip.',
        description:
            'A leather case contoured to allow quick draw of archery arrows in combat.',
        properties: [
          'Capacity: 20 arrows.',
          'Weight: 1 lb.',
          'Cost: 1 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Holds up to 20 arrows comfortably over the shoulder or on the hip.',
        description:
            'A leather case contoured to allow quick draw of archery arrows in combat.',
        properties: [
          'Capacity: 20 arrows.',
          'Weight: 1 lb.',
          'Cost: 1 gp.',
        ],
      ),
      tags: ['gear', 'container', 'ammunition', 'bow'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'container', 'ammunition', 'bow'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'sack', ruleset: RulesetVersion.v2024), name: 'Sack',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Holds 1 cubic foot or 30 pounds of gear.',
      rules2014: ItemEditionDetails(
        summary: 'Holds 1 cubic foot or 30 pounds of gear.',
        description: 'A simple burlap or canvas sack tied off with twine.',
        properties: [
          'Capacity: 1 cubic foot / 30 pounds.',
          'Weight: ½ lb.',
          'Cost: 1 cp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Holds 1 cubic foot or 30 pounds of gear.',
        description: 'A simple burlap or canvas sack tied off with twine.',
        properties: [
          'Capacity: 1 cubic foot / 30 pounds.',
          'Weight: ½ lb.',
          'Cost: 1 cp.',
        ],
      ),
      tags: ['gear', 'container', 'storage'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'container', 'storage'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'vial', ruleset: RulesetVersion.v2024), name: 'Vial',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Holds up to 4 ounces of liquid, suitable for poisons, acids, or holy water.',
      rules2014: ItemEditionDetails(
        summary:
            'Holds up to 4 ounces of liquid, suitable for poisons, acids, or holy water.',
        description:
            'A small glass or crystal cylindrical tube with a wax seal.',
        properties: [
          'Capacity: 4 fluid ounces.',
          'Weight: negligible.',
          'Cost: 1 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Holds up to 4 ounces of liquid, suitable for poisons, acids, or holy water.',
        description:
            'A small glass or crystal cylindrical tube with a wax seal.',
        properties: [
          'Capacity: 4 fluid ounces.',
          'Weight: negligible.',
          'Cost: 1 gp.',
        ],
      ),
      tags: ['gear', 'container', 'liquid'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'container', 'liquid'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'waterskin', ruleset: RulesetVersion.v2024), name: 'Waterskin',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Holds 4 pints (half a gallon) of liquid.',
      rules2014: ItemEditionDetails(
        summary: 'Holds 4 pints (half a gallon) of liquid.',
        description: 'A leather bladder with a wooden plug and shoulder strap.',
        properties: [
          'Capacity: 4 pints liquid.',
          'Weight: 5 lbs (full).',
          'Cost: 2 sp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Holds 4 pints (half a gallon) of liquid.',
        description: 'A leather bladder with a wooden plug and shoulder strap.',
        properties: [
          'Capacity: 4 pints liquid.',
          'Weight: 5 lbs (full).',
          'Cost: 2 sp.',
        ],
      ),
      tags: ['gear', 'container', 'survival'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'container', 'survival'] },
    ),

    // =========================================================================
    // 2. ADVENTURING UTILITY, SURVIVAL & EXPLORATION
    // =========================================================================
    EquipmentItem(
      id: EntityId(slug: 'abacus', ruleset: RulesetVersion.v2024), name: 'Abacus',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Standard wooden counting frame with beads for rapid bookkeeping and mathematical calculation.',
      rules2014: ItemEditionDetails(
        summary:
            'Standard wooden counting frame with beads for rapid bookkeeping and mathematical calculation.',
        description:
            'A framed calculating device widely used by merchants, tax collectors, and scholars.',
        properties: [
          'Weight: 2 lbs.',
          'Cost: 2 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Standard wooden counting frame with beads for rapid bookkeeping and mathematical calculation.',
        description:
            'A framed calculating device widely used by merchants, tax collectors, and scholars.',
        properties: [
          'Weight: 2 lbs.',
          'Cost: 2 gp.',
        ],
      ),
      tags: ['gear', 'calculation', 'mercantile'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'calculation', 'mercantile'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'acid_vial', ruleset: RulesetVersion.v2024), name: 'Acid (Vial)',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Improvised ranged attack (range 20 ft). On hit, deals 2d6 acid damage.',
      rules2014: ItemEditionDetails(
        summary:
            'Improvised ranged attack (range 20 ft). On hit, deals 2d6 acid damage.',
        description: 'A concentrated vial of highly caustic dissolving acid.',
        activation: '1 Action',
        properties: [
          'Ranged Improvised Weapon (20 ft).',
          'Deals 2d6 acid damage on hit.',
          'Weight: 1 lb.',
          'Cost: 25 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Improvised ranged attack (range 20 ft). On hit, deals 2d6 acid damage.',
        description: 'A concentrated vial of highly caustic dissolving acid.',
        activation: '1 Action',
        properties: [
          'Ranged Improvised Weapon (20 ft).',
          'Deals 2d6 acid damage on hit.',
          'Weight: 1 lb.',
          'Cost: 25 gp.',
        ],
      ),
      tags: ['gear', 'acid', 'corrosive', 'combat', 'utility'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'acid', 'corrosive', 'combat', 'utility'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'alchemists_fire', ruleset: RulesetVersion.v2024), name: 'Alchemist\'s Fire (Flask)',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Ranged attack (20 ft). On hit, target takes 1d4 fire damage at start of each turn until extinguished with a DC 10 Dex check.',
      rules2014: ItemEditionDetails(
        summary:
            'Ranged attack (20 ft). On hit, target takes 1d4 fire damage at start of each of its turns until extinguished with a DC 10 Dex check.',
        description:
            'A volatile sticky fluid that ignites when exposed to air.',
        activation: '1 Action',
        properties: [
          'Ranged Improvised Weapon (20 ft).',
          '1d4 fire damage at turn start until DC 10 Dexterity action extinguishes.',
          'Weight: 1 lb.',
          'Cost: 50 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Ranged attack (20 ft). On hit, target takes 1d4 fire damage at start of each turn until extinguished with a DC 10 Dex check.',
        description:
            'A volatile sticky fluid that ignites when exposed to air.',
        activation: '1 Action',
        properties: [
          'Ranged Improvised Weapon (20 ft).',
          '1d4 fire damage per turn until put out.',
          'Weight: 1 lb.',
          'Cost: 50 gp.',
        ],
      ),
      tags: ['gear', 'fire', 'combustible', 'combat'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'fire', 'combustible', 'combat'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'antitoxin', ruleset: RulesetVersion.v2024), name: 'Antitoxin (Vial)',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Drinking this provides Advantage on saving throws against poison for 1 hour.',
      rules2014: ItemEditionDetails(
        summary:
            'Drinking this provides Advantage on saving throws against poison for 1 hour.',
        description:
            'A bitter herbal distillation that neutralizes toxins and venom.',
        activation: '1 Action',
        properties: [
          'Advantage on saving throws against poison for 1 hour.',
          'Weight: negligible.',
          'Cost: 50 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Drinking this provides Advantage on saving throws against poison for 1 hour.',
        description:
            'A bitter herbal distillation that neutralizes toxins and venom.',
        activation: '1 Action',
        properties: [
          'Advantage on saving throws against poison for 1 hour.',
          'Weight: negligible.',
          'Cost: 50 gp.',
        ],
      ),
      tags: ['gear', 'poison', 'medicine', 'defense'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'poison', 'medicine', 'defense'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'ball_bearings', ruleset: RulesetVersion.v2024), name: 'Ball Bearings (Bag of 1,000)',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Cover a 10-foot square. Moving through at normal speed requires a DC 10 Dexterity save or fall Prone.',
      rules2014: ItemEditionDetails(
        summary:
            'Cover a 10-foot square. Moving through at normal speed requires a DC 10 Dexterity save or fall Prone.',
        description:
            'A pouch of 1,000 miniature metal spheres to create slick hazards.',
        activation: '1 Action',
        properties: [
          'Covers 10-foot square area.',
          'DC 10 Dexterity saving throw or fall Prone.',
          'Weight: 2 lbs.',
          'Cost: 1 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Cover a 10-foot square. Moving through at normal speed requires a DC 10 Dexterity save or fall Prone.',
        description:
            'A pouch of 1,000 miniature metal spheres to create slick hazards.',
        activation: '1 Action',
        properties: [
          'Covers 10-foot square area.',
          'DC 10 Dexterity saving throw or fall Prone.',
          'Weight: 2 lbs.',
          'Cost: 1 gp.',
        ],
      ),
      tags: ['gear', 'hazard', 'control', 'prone'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'hazard', 'control', 'prone'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'bedroll', ruleset: RulesetVersion.v2024), name: 'Bedroll',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Comfortable padded sleeping roll for taking short and long rests in the wild.',
      rules2014: ItemEditionDetails(
        summary:
            'Comfortable padded sleeping roll for taking short and long rests in the wild.',
        description:
            'A quilted blanket and waterproof ground cloth rolled together with leather straps.',
        properties: [
          'Weight: 7 lbs.',
          'Cost: 1 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Comfortable padded sleeping roll for taking short and long rests in the wild.',
        description:
            'A quilted blanket and waterproof ground cloth rolled together with leather straps.',
        properties: [
          'Weight: 7 lbs.',
          'Cost: 1 gp.',
        ],
      ),
      tags: ['gear', 'camp', 'rest', 'equipment'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'camp', 'rest', 'equipment'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'bell', ruleset: RulesetVersion.v2024), name: 'Bell',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Small brass bell used for tripwire traps, camp alarms, or summoning calls.',
      rules2014: ItemEditionDetails(
        summary:
            'Small brass bell used for tripwire traps, camp alarms, or summoning calls.',
        description:
            'A resonant metal bell that rings cleanly across quiet dungeon corridors.',
        properties: [
          'Weight: negligible.',
          'Cost: 1 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Small brass bell used for tripwire traps, camp alarms, or summoning calls.',
        description:
            'A resonant metal bell that rings cleanly across quiet dungeon corridors.',
        properties: [
          'Weight: negligible.',
          'Cost: 1 gp.',
        ],
      ),
      tags: ['gear', 'alarm', 'signal', 'sound'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'alarm', 'signal', 'sound'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'blanket', ruleset: RulesetVersion.v2024), name: 'Blanket',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Thick woven wool blanket for insulation against hypothermia and cold environments.',
      rules2014: ItemEditionDetails(
        summary:
            'Thick woven wool blanket for insulation against hypothermia and cold environments.',
        description:
            'A durable wool blanket providing warmth during harsh wilderness expeditions.',
        properties: [
          'Weight: 3 lbs.',
          'Cost: 5 sp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Thick woven wool blanket for insulation against hypothermia and cold environments.',
        description:
            'A durable wool blanket providing warmth during harsh wilderness expeditions.',
        properties: [
          'Weight: 3 lbs.',
          'Cost: 5 sp.',
        ],
      ),
      tags: ['gear', 'warmth', 'camp', 'survival'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'warmth', 'camp', 'survival'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'block_and_tackle', ruleset: RulesetVersion.v2024), name: 'Block and Tackle',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Pulleys and tackle allowing a creature to hoist up to 4 times the weight it can normally lift.',
      rules2014: ItemEditionDetails(
        summary:
            'Pulleys and tackle allowing a creature to hoist up to 4 times the weight it can normally lift.',
        description:
            'A system of grooved wheels and cable blocks for heavy architectural and salvage work.',
        properties: [
          'Multiplies lifting capacity by 4.',
          'Weight: 5 lbs.',
          'Cost: 1 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Pulleys and tackle allowing a creature to hoist up to 4 times the weight it can normally lift.',
        description:
            'A system of grooved wheels and cable blocks for heavy architectural and salvage work.',
        properties: [
          'Multiplies lifting capacity by 4.',
          'Weight: 5 lbs.',
          'Cost: 1 gp.',
        ],
      ),
      tags: ['gear', 'utility', 'lifting', 'engineering'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'utility', 'lifting', 'engineering'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'book', ruleset: RulesetVersion.v2024), name: 'Book',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'A bound volume containing poetry, history, religious scriptures, or technical treatises.',
      rules2014: ItemEditionDetails(
        summary:
            'A bound volume containing poetry, history, religious scriptures, or technical treatises.',
        description:
            'A leather-bound folio containing illuminated parchment or paper pages.',
        properties: [
          'Weight: 5 lbs.',
          'Cost: 25 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'A bound volume containing poetry, history, religious scriptures, or technical treatises.',
        description:
            'A leather-bound folio containing illuminated parchment or paper pages.',
        properties: [
          'Weight: 5 lbs.',
          'Cost: 25 gp.',
        ],
      ),
      tags: ['gear', 'scholarship', 'history', 'lore'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'scholarship', 'history', 'lore'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'caltrops', ruleset: RulesetVersion.v2024), name: 'Caltrops (Bag of 20)',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Covers a 5-foot square. Entering creature must succeed on DC 15 Dex save or take 1 piercing damage and speed reduced by 10 ft until healed.',
      rules2014: ItemEditionDetails(
        summary:
            'Covers a 5-foot square. Entering creature must succeed on DC 15 Dex save or take 1 piercing damage and speed reduced by 10 ft until healed.',
        description:
            'A bag of 20 four-spiked iron caltrops that always land with one point upward.',
        activation: '1 Action',
        properties: [
          'Covers 5-foot square.',
          'DC 15 Dexterity save or 1 piercing damage and -10 ft Speed until HP regained.',
          'Weight: 2 lbs.',
          'Cost: 1 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Covers a 5-foot square. Entering creature must succeed on DC 15 Dex save or take 1 piercing damage and speed reduced by 10 ft until healed.',
        description:
            'A bag of 20 four-spiked iron caltrops that always land with one point upward.',
        activation: '1 Action',
        properties: [
          'Covers 5-foot square.',
          'DC 15 Dexterity save or 1 piercing damage and -10 ft Speed.',
          'Weight: 2 lbs.',
          'Cost: 1 gp.',
        ],
      ),
      tags: ['gear', 'hazard', 'control', 'piercing'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'hazard', 'control', 'piercing'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'candle', ruleset: RulesetVersion.v2024), name: 'Candle',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Burns for 1 hour, shedding bright light in a 5-foot radius and dim light for an additional 5 feet.',
      rules2014: ItemEditionDetails(
        summary:
            'Burns for 1 hour, shedding bright light in a 5-foot radius and dim light for an additional 5 feet.',
        description: 'A standard tallow or beeswax candle.',
        properties: [
          'Bright light: 5-ft radius; Dim light: additional 5 ft.',
          'Burns for 1 hour.',
          'Weight: negligible.',
          'Cost: 1 cp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Burns for 1 hour, shedding bright light in a 5-foot radius and dim light for an additional 5 feet.',
        description: 'A standard tallow or beeswax candle.',
        properties: [
          'Bright light: 5-ft radius; Dim light: additional 5 ft.',
          'Burns for 1 hour.',
          'Weight: negligible.',
          'Cost: 1 cp.',
        ],
      ),
      tags: ['gear', 'light', 'fire', 'utility'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'light', 'fire', 'utility'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'chain_10ft', ruleset: RulesetVersion.v2024), name: 'Chain (10 Feet)',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: '10-foot iron chain. Has AC 19, 10 hit points, and burst DC 20 Strength.',
      rules2014: ItemEditionDetails(
        summary:
            '10-foot iron chain. Has AC 19, 10 hit points, and burst DC 20 Strength.',
        description:
            'Heavy welded iron links used to bind prisoners, secure portcullises, and anchor vehicles.',
        properties: [
          'AC: 19; HP: 10; Burst DC: 20 Strength.',
          'Weight: 10 lbs.',
          'Cost: 5 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            '10-foot iron chain. Has AC 19, 10 hit points, and burst DC 20 Strength.',
        description:
            'Heavy welded iron links used to bind prisoners, secure portcullises, and anchor vehicles.',
        properties: [
          'AC: 19; HP: 10; Burst DC: 20 Strength.',
          'Weight: 10 lbs.',
          'Cost: 5 gp.',
        ],
      ),
      tags: ['gear', 'restraint', 'utility', 'metal'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'restraint', 'utility', 'metal'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'chalk', ruleset: RulesetVersion.v2024), name: 'Chalk (1 Piece)',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Used to draw symbols, directional markers, and dungeon path codes on stone and wood.',
      rules2014: ItemEditionDetails(
        summary:
            'Used to draw symbols, directional markers, and dungeon path codes on stone and wood.',
        description: 'A stick of soft limestone or calcium carbonate.',
        properties: [
          'Weight: negligible.',
          'Cost: 1 cp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Used to draw symbols, directional markers, and dungeon path codes on stone and wood.',
        description: 'A stick of soft limestone or calcium carbonate.',
        properties: [
          'Weight: negligible.',
          'Cost: 1 cp.',
        ],
      ),
      tags: ['gear', 'marking', 'navigation', 'utility'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'marking', 'navigation', 'utility'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'climbers_kit', ruleset: RulesetVersion.v2024), name: 'Climber\'s Kit',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Includes pitons, boot tips, gloves, and harness. Allows anchoring oneself so a fall drops no more than 25 feet.',
      rules2014: ItemEditionDetails(
        summary:
            'Includes pitons, boot tips, gloves, and harness. Allows anchoring oneself so a fall drops no more than 25 feet.',
        description:
            'Specialized ascender gear and safety anchors for scaling sheer cliff faces.',
        properties: [
          'Prevents falling more than 25 feet while anchored.',
          'Weight: 12 lbs.',
          'Cost: 25 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Includes pitons, boot tips, gloves, and harness. Allows anchoring oneself so a fall drops no more than 25 feet.',
        description:
            'Specialized ascender gear and safety anchors for scaling sheer cliff faces.',
        properties: [
          'Prevents falling more than 25 feet while anchored.',
          'Weight: 12 lbs.',
          'Cost: 25 gp.',
        ],
      ),
      tags: ['gear', 'climbing', 'safety', 'harness'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'climbing', 'safety', 'harness'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'component_pouch', ruleset: RulesetVersion.v2024), name: 'Component Pouch',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Waterproof belt pouch compartmentalized to hold all non-costly spell material components.',
      rules2014: ItemEditionDetails(
        summary:
            'Waterproof belt pouch compartmentalized to hold all non-costly spell material components.',
        description:
            'A multi-pocketed leather pouch holding pinches of sulfur, feathers, bat fur, and other spell reagents.',
        properties: [
          'Provides all material components lacking a gp cost.',
          'Weight: 2 lbs.',
          'Cost: 25 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Waterproof belt pouch compartmentalized to hold all non-costly spell material components.',
        description:
            'A multi-pocketed leather pouch holding pinches of sulfur, feathers, bat fur, and other spell reagents.',
        properties: [
          'Provides all material components lacking a gp cost.',
          'Weight: 2 lbs.',
          'Cost: 25 gp.',
        ],
      ),
      tags: ['gear', 'spellcasting', 'arcane', 'divine', 'focus'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'spellcasting', 'arcane', 'divine', 'focus'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'crowbar', ruleset: RulesetVersion.v2024), name: 'Crowbar',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Grants Advantage on Strength (Athletics) checks where leverage is applicable.',
      rules2014: ItemEditionDetails(
        summary:
            'Grants Advantage on Strength checks where the crowbar\'s leverage can be applied.',
        description:
            'A sturdy iron bar with a flattened, curved end designed for prying open stuck doors and chests.',
        properties: [
          'Advantage on applicable Strength ability checks.',
          'Weight: 5 lbs.',
          'Cost: 2 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Grants Advantage on Strength (Athletics) checks where leverage is applicable.',
        description:
            'A sturdy iron bar with a flattened, curved end designed for prying open stuck doors and chests.',
        properties: [
          'Advantage on applicable Strength checks.',
          'Weight: 5 lbs.',
          'Cost: 2 gp.',
        ],
      ),
      tags: ['gear', 'tool', 'utility', 'leverage'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'tool', 'utility', 'leverage'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'druidic_focus', ruleset: RulesetVersion.v2024), name: 'Druidic Focus (Sprig of Mistletoe / Totem / Wooden Staff / Yew Wand)',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'A special nature focus used to channel druid spells without non-costly components.',
      rules2014: ItemEditionDetails(
        summary:
            'A special nature focus (sprig of mistletoe, totem, wooden staff, or yew wand) used to channel druid spells.',
        description:
            'A consecrated symbol of natural order, replacing non-costly material components for druid and ranger spellcasting.',
        properties: [
          'Replaces non-costly material components for Druid spells.',
          'Weight: 1–4 lbs.',
          'Cost: 1–10 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'A special nature focus used to channel druid spells without non-costly components.',
        description:
            'A consecrated symbol of natural order, replacing non-costly material components for druid and ranger spellcasting.',
        properties: [
          'Replaces non-costly material components for Druid spells.',
          'Weight: 1–4 lbs.',
          'Cost: 1–10 gp.',
        ],
      ),
      tags: ['gear', 'focus', 'druid', 'nature', 'spellcasting'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'focus', 'druid', 'nature', 'spellcasting'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'fishing_tackle', ruleset: RulesetVersion.v2024), name: 'Fishing Tackle',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Includes a wooden rod, silken line, cork bobbers, steel hooks, lead sinkers, and bait lures.',
      rules2014: ItemEditionDetails(
        summary:
            'Includes a wooden rod, silken line, cork bobbers, steel hooks, lead sinkers, and bait lures.',
        description:
            'A complete kit for harvesting fish in wilderness rivers, lakes, and oceans during travel.',
        properties: [
          'Weight: 4 lbs.',
          'Cost: 1 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Includes a wooden rod, silken line, cork bobbers, steel hooks, lead sinkers, and bait lures.',
        description:
            'A complete kit for harvesting fish in wilderness rivers, lakes, and oceans during travel.',
        properties: [
          'Weight: 4 lbs.',
          'Cost: 1 gp.',
        ],
      ),
      tags: ['gear', 'survival', 'food', 'foraging'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'survival', 'food', 'foraging'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'grappling_hook', ruleset: RulesetVersion.v2024), name: 'Grappling Hook',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Four-pronged iron hook tied to a rope to secure climbs over walls and ledges.',
      rules2014: ItemEditionDetails(
        summary:
            'Four-pronged iron hook tied to a rope to secure climbs over walls and ledges.',
        description:
            'An anchor hook forged of resilient iron, essential for scale ascents and securing rope lines.',
        properties: [
          'Weight: 4 lbs.',
          'Cost: 2 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Four-pronged iron hook tied to a rope to secure climbs over walls and ledges.',
        description:
            'An anchor hook forged of resilient iron, essential for scale ascents and securing rope lines.',
        properties: [
          'Weight: 4 lbs.',
          'Cost: 2 gp.',
        ],
      ),
      tags: ['gear', 'climbing', 'utility'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'climbing', 'utility'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'hammer', ruleset: RulesetVersion.v2024), name: 'Hammer',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'One-handed utility hammer for driving iron spikes and carpentry work.',
      rules2014: ItemEditionDetails(
        summary:
            'One-handed utility hammer for driving iron spikes and carpentry work.',
        description:
            'A flat-headed tool designed for driving pitons and iron spikes.',
        properties: [
          'Weight: 3 lbs.',
          'Cost: 1 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'One-handed utility hammer for driving iron spikes and carpentry work.',
        description:
            'A flat-headed tool designed for driving pitons and iron spikes.',
        properties: [
          'Weight: 3 lbs.',
          'Cost: 1 gp.',
        ],
      ),
      tags: ['gear', 'tool', 'construction', 'bludgeoning'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'tool', 'construction', 'bludgeoning'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'hammer_sledge', ruleset: RulesetVersion.v2024), name: 'Hammer, Sledge',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Heavy two-handed sledgehammer for demolition, breaking stone, and shattering locks.',
      rules2014: ItemEditionDetails(
        summary:
            'Heavy two-handed sledgehammer for demolition, breaking stone, and shattering locks.',
        description: 'A massive iron hammerhead mounted on a long wooden haft.',
        properties: [
          'Weight: 10 lbs.',
          'Cost: 2 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Heavy two-handed sledgehammer for demolition, breaking stone, and shattering locks.',
        description: 'A massive iron hammerhead mounted on a long wooden haft.',
        properties: [
          'Weight: 10 lbs.',
          'Cost: 2 gp.',
        ],
      ),
      tags: ['gear', 'tool', 'demolition', 'heavy', 'bludgeoning'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'tool', 'demolition', 'heavy', 'bludgeoning'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'healers_kit', ruleset: RulesetVersion.v2024), name: 'Healer\'s Kit',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Contains 10 uses. As an action, expend 1 use to stabilize a dying creature without making a Medicine check.',
      rules2014: ItemEditionDetails(
        summary:
            'Contains 10 uses. As an action, expend 1 use to stabilize a dying creature without making a Medicine check.',
        description:
            'A leather pouch containing bandages, salves, and splints to treat battlefield casualties.',
        activation: '1 Action',
        properties: [
          '10 uses per kit.',
          'Stabilizes a creature at 0 HP with no roll required.',
          'Weight: 3 lbs.',
          'Cost: 5 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Contains 10 uses. As an action, expend 1 use to stabilize a dying creature without making a Medicine check.',
        description:
            'A leather pouch containing bandages, salves, and splints to treat battlefield casualties.',
        activation: '1 Action',
        properties: [
          '10 uses per kit.',
          'Stabilizes a creature at 0 HP with no check.',
          'Weight: 3 lbs.',
          'Cost: 5 gp.',
        ],
      ),
      tags: ['gear', 'healing', 'stabilize', 'medical', 'sustain'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'healing', 'stabilize', 'medical', 'sustain'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'holy_water', ruleset: RulesetVersion.v2024), name: 'Holy Water (Flask)',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Improvised ranged attack (range 20 ft). On hit against a Fiend or Undead, deals 2d6 radiant damage.',
      rules2014: ItemEditionDetails(
        summary:
            'Improvised ranged attack (range 20 ft). On hit against a Fiend or Undead, deals 2d6 radiant damage.',
        description:
            'Water blessed by a cleric or paladin through a ritual in a consecrated sanctuary.',
        activation: '1 Action',
        properties: [
          'Ranged Improvised Weapon Attack (20 ft).',
          'Deals 2d6 radiant damage against Fiends and Undead.',
          'Weight: 1 lb.',
          'Cost: 25 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Improvised ranged attack (range 20 ft). On hit against a Fiend or Undead, deals 2d6 radiant damage.',
        description:
            'Water blessed by a cleric or paladin through a ritual in a consecrated sanctuary.',
        activation: '1 Action',
        properties: [
          'Ranged Improvised Weapon Attack (20 ft).',
          'Deals 2d6 radiant damage against Fiends and Undead.',
          'Weight: 1 lb.',
          'Cost: 25 gp.',
        ],
      ),
      tags: ['gear', 'radiant', 'undead', 'fiend', 'combat'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'radiant', 'undead', 'fiend', 'combat'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'hourglass', ruleset: RulesetVersion.v2024), name: 'Hourglass',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Standard sand timer measuring one exact hour of elapsed duration.',
      rules2014: ItemEditionDetails(
        summary:
            'Standard sand timer measuring one exact hour of elapsed duration.',
        description:
            'Two connected glass bulbs filled with fine measured sand in a protective brass or wooden frame.',
        properties: [
          'Weight: 1 lb.',
          'Cost: 25 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Standard sand timer measuring one exact hour of elapsed duration.',
        description:
            'Two connected glass bulbs filled with fine measured sand in a protective brass or wooden frame.',
        properties: [
          'Weight: 1 lb.',
          'Cost: 25 gp.',
        ],
      ),
      tags: ['gear', 'time', 'navigation', 'utility'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'time', 'navigation', 'utility'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'hunting_trap', ruleset: RulesetVersion.v2024), name: 'Hunting Trap',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Stepping on the trap requires a DC 13 Dex save or take 1d4 piercing damage and stop moving until escaping with a DC 13 Str check.',
      rules2014: ItemEditionDetails(
        summary:
            'Stepping on the trap requires a DC 13 Dex save or take 1d4 piercing damage and stop moving until escaping with a DC 13 Str check.',
        description:
            'A heavy spring-loaded iron jaw anchored by a chain to a spike.',
        activation: '1 Action',
        properties: [
          'DC 13 Dexterity save or 1d4 piercing damage and immobilized.',
          'Escape requires DC 13 Strength check.',
          'Weight: 25 lbs.',
          'Cost: 5 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Stepping on the trap requires a DC 13 Dex save or take 1d4 piercing damage and stop moving until escaping with a DC 13 Str check.',
        description:
            'A heavy spring-loaded iron jaw anchored by a chain to a spike.',
        activation: '1 Action',
        properties: [
          'DC 13 Dexterity save or 1d4 piercing damage and immobilized.',
          'Escape requires DC 13 Strength check.',
          'Weight: 25 lbs.',
          'Cost: 5 gp.',
        ],
      ),
      tags: ['gear', 'trap', 'restrain', 'control', 'piercing'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'trap', 'restrain', 'control', 'piercing'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'ink_bottle', ruleset: RulesetVersion.v2024), name: 'Ink (1 Ounce Bottle)',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: '1 ounce bottle of black or dark sepia ink for scribing scrolls, maps, and spellbook pages.',
      rules2014: ItemEditionDetails(
        summary:
            '1 ounce bottle of black or dark sepia ink for scribing scrolls, maps, and spellbook pages.',
        description:
            'High-grade gall or carbon ink stored in a stoppered glass vial.',
        properties: [
          'Weight: negligible.',
          'Cost: 10 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            '1 ounce bottle of black or dark sepia ink for scribing scrolls, maps, and spellbook pages.',
        description:
            'High-grade gall or carbon ink stored in a stoppered glass vial.',
        properties: [
          'Weight: negligible.',
          'Cost: 10 gp.',
        ],
      ),
      tags: ['gear', 'writing', 'scrolls', 'spellbook'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'writing', 'scrolls', 'spellbook'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'ink_pen', ruleset: RulesetVersion.v2024), name: 'Ink Pen',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Quill or dip pen with a carved wooden or metal nib for writing with ink.',
      rules2014: ItemEditionDetails(
        summary:
            'Quill or dip pen with a carved wooden or metal nib for writing with ink.',
        description:
            'A sturdy writing pen for cartography, legal contracts, and arcane study.',
        properties: [
          'Weight: negligible.',
          'Cost: 2 cp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Quill or dip pen with a carved wooden or metal nib for writing with ink.',
        description:
            'A sturdy writing pen for cartography, legal contracts, and arcane study.',
        properties: [
          'Weight: negligible.',
          'Cost: 2 cp.',
        ],
      ),
      tags: ['gear', 'writing', 'scholarship'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'writing', 'scholarship'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'ladder_10ft', ruleset: RulesetVersion.v2024), name: 'Ladder (10-Foot)',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: '10-foot wooden ladder with reinforced rungs.',
      rules2014: ItemEditionDetails(
        summary: '10-foot wooden ladder with reinforced rungs.',
        description:
            'A simple timber ladder for scaling roofs, dungeon drop-offs, and pit traps.',
        properties: [
          'Height: 10 feet.',
          'Weight: 25 lbs.',
          'Cost: 1 sp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: '10-foot wooden ladder with reinforced rungs.',
        description:
            'A simple timber ladder for scaling roofs, dungeon drop-offs, and pit traps.',
        properties: [
          'Height: 10 feet.',
          'Weight: 25 lbs.',
          'Cost: 1 sp.',
        ],
      ),
      tags: ['gear', 'climbing', 'utility'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'climbing', 'utility'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'lamp', ruleset: RulesetVersion.v2024), name: 'Lamp',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Casts bright light in a 15-foot radius and dim light for an additional 30 feet for 6 hours on 1 flask of oil.',
      rules2014: ItemEditionDetails(
        summary:
            'Casts bright light in a 15-foot radius and dim light for an additional 30 feet for 6 hours on 1 flask of oil.',
        description: 'A small clay or brass oil lamp with a wick spout.',
        properties: [
          'Bright light: 15-ft radius; Dim light: additional 30 ft.',
          'Burns for 6 hours on 1 flask of oil.',
          'Weight: 1 lb.',
          'Cost: 5 sp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Casts bright light in a 15-foot radius and dim light for an additional 30 feet for 6 hours on 1 flask of oil.',
        description: 'A small clay or brass oil lamp with a wick spout.',
        properties: [
          'Bright light: 15-ft radius; Dim light: additional 30 ft.',
          'Burns for 6 hours on 1 flask of oil.',
          'Weight: 1 lb.',
          'Cost: 5 sp.',
        ],
      ),
      tags: ['gear', 'light', 'oil', 'vision'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'light', 'oil', 'vision'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'bullseye_lantern', ruleset: RulesetVersion.v2024), name: 'Lantern, Bullseye',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Casts bright light in a 60-foot cone and dim light for an additional 60 feet for 6 hours on 1 flask of oil.',
      rules2014: ItemEditionDetails(
        summary:
            'Casts bright light in a 60-foot cone and dim light for an additional 60 feet for 6 hours on 1 flask of oil.',
        description:
            'A hooded lantern with an adjustable shutter and reflective lens to focus light in a long directional beam.',
        properties: [
          'Bright light: 60-ft cone; Dim light: additional 60 ft.',
          'Burns for 6 hours per 1 pint (flask) of oil.',
          'Weight: 2 lbs.',
          'Cost: 10 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Casts bright light in a 60-foot cone and dim light for an additional 60 feet for 6 hours on 1 flask of oil.',
        description:
            'A hooded lantern with an adjustable shutter and reflective lens to focus light in a long directional beam.',
        properties: [
          'Bright light: 60-ft cone; Dim light: additional 60 ft.',
          'Burns for 6 hours per flask of oil.',
          'Weight: 2 lbs.',
          'Cost: 10 gp.',
        ],
      ),
      tags: ['gear', 'light', 'vision', 'exploration'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'light', 'vision', 'exploration'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'hooded_lantern', ruleset: RulesetVersion.v2024), name: 'Lantern, Hooded',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Casts bright light in a 30-foot radius and dim light for an additional 30 feet for 6 hours on 1 flask of oil.',
      rules2014: ItemEditionDetails(
        summary:
            'Casts bright light in a 30-foot radius and dim light for an additional 30 feet for 6 hours on 1 flask of oil.',
        description:
            'A cylindrical glass lantern with a movable metal hood that can be lowered to reduce light to 5-foot dim light.',
        properties: [
          'Bright light: 30-ft radius; Dim light: additional 30 ft.',
          'Hood down: 5-ft dim light.',
          'Weight: 2 lbs.',
          'Cost: 5 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Casts bright light in a 30-foot radius and dim light for an additional 30 feet for 6 hours on 1 flask of oil.',
        description:
            'A cylindrical glass lantern with a movable metal hood that can be lowered to reduce light to 5-foot dim light.',
        properties: [
          'Bright light: 30-ft radius; Dim light: additional 30 ft.',
          'Hood down: 5-ft dim light.',
          'Weight: 2 lbs.',
          'Cost: 5 gp.',
        ],
      ),
      tags: ['gear', 'light', 'vision', 'exploration'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'light', 'vision', 'exploration'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'lock', ruleset: RulesetVersion.v2024), name: 'Lock',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Comes with a key. Opening without key requires a DC 15 Dexterity (Sleight of Hand) check using Thieves\' Tools.',
      rules2014: ItemEditionDetails(
        summary:
            'Comes with a key. Opening without key requires a DC 15 Thieves\' Tools check.',
        description: 'An iron padlock with a brass tumbler mechanism.',
        properties: [
          'DC 15 Thieves\' Tools check to pick.',
          'Weight: 1 lb.',
          'Cost: 10 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Comes with a key. Opening without key requires a DC 15 Dexterity (Sleight of Hand) check using Thieves\' Tools.',
        description: 'An iron padlock with a brass tumbler mechanism.',
        properties: [
          'DC 15 Thieves\' Tools check to pick.',
          'Weight: 1 lb.',
          'Cost: 10 gp.',
        ],
      ),
      tags: ['gear', 'security', 'locks', 'doors'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'security', 'locks', 'doors'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'magnifying_glass', ruleset: RulesetVersion.v2024), name: 'Magnifying Glass',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Grants Advantage on ability checks made to inspect small or detailed objects. Can start a fire under bright sunlight.',
      rules2014: ItemEditionDetails(
        summary:
            'Grants Advantage on ability checks made to appraise or inspect small or detailed items. Can light tinder in direct sunlight.',
        description:
            'A convex glass lens mounted in a polished brass rim with a handle.',
        properties: [
          'Advantage on detailed appraisal and examination checks.',
          'Lights tinder in 5 minutes under direct sunlight.',
          'Weight: negligible.',
          'Cost: 100 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Grants Advantage on ability checks made to inspect small or detailed objects. Can start a fire under bright sunlight.',
        description:
            'A convex glass lens mounted in a polished brass rim with a handle.',
        properties: [
          'Advantage on detailed investigation and appraisal checks.',
          'Weight: negligible.',
          'Cost: 100 gp.',
        ],
      ),
      tags: ['gear', 'investigation', 'optical', 'fire'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'investigation', 'optical', 'fire'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'manacles', ruleset: RulesetVersion.v2024), name: 'Manacles',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Binds a Small or Medium creature. Escaping requires DC 20 Dex check; breaking requires DC 20 Str check; picking requires DC 15 Thieves\' Tools.',
      rules2014: ItemEditionDetails(
        summary:
            'Binds a Small or Medium creature. Escaping requires DC 20 Dex check; breaking requires DC 20 Str check; picking requires DC 15 Thieves\' Tools.',
        description:
            'A pair of hinged iron wrist shackles connected by welded chain links.',
        properties: [
          'Escape DC: 20 Dexterity; Break DC: 20 Strength; Pick DC: 15 Thieves\' Tools.',
          'Weight: 6 lbs.',
          'Cost: 2 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Binds a Small or Medium creature. Escaping requires DC 20 Dex check; breaking requires DC 20 Str check; picking requires DC 15 Thieves\' Tools.',
        description:
            'A pair of hinged iron wrist shackles connected by welded chain links.',
        properties: [
          'Escape DC: 20 Dexterity; Break DC: 20 Strength; Pick DC: 15 Thieves\' Tools.',
          'Weight: 6 lbs.',
          'Cost: 2 gp.',
        ],
      ),
      tags: ['gear', 'restraint', 'security', 'control'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'restraint', 'security', 'control'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'mess_kit', ruleset: RulesetVersion.v2024), name: 'Mess Kit',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Contains a cup and simple cutlery. The box clamps together to store the pieces and can serve as a cooking pan.',
      rules2014: ItemEditionDetails(
        summary:
            'Contains a cup and simple cutlery. The box clamps together to store the pieces and can serve as a cooking pan.',
        description:
            'A nesting metal container holding a plate, bowl, cup, fork, and spoon.',
        properties: [
          'Weight: 1 lb.',
          'Cost: 2 sp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Contains a cup and simple cutlery. The box clamps together to store the pieces and can serve as a cooking pan.',
        description:
            'A nesting metal container holding a plate, bowl, cup, fork, and spoon.',
        properties: [
          'Weight: 1 lb.',
          'Cost: 2 sp.',
        ],
      ),
      tags: ['gear', 'camp', 'dining', 'survival'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'camp', 'dining', 'survival'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'mirror_steel', ruleset: RulesetVersion.v2024), name: 'Mirror, Steel',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Polished steel reflective hand mirror used for looking around corners or signaling over long distances.',
      rules2014: ItemEditionDetails(
        summary:
            'Polished steel reflective hand mirror used for looking around corners or signaling over long distances.',
        description:
            'A polished metal plate that does not shatter like glass when struck.',
        properties: [
          'Weight: ½ lb.',
          'Cost: 5 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Polished steel reflective hand mirror used for looking around corners or signaling over long distances.',
        description:
            'A polished metal plate that does not shatter like glass when struck.',
        properties: [
          'Weight: ½ lb.',
          'Cost: 5 gp.',
        ],
      ),
      tags: ['gear', 'scouting', 'signaling', 'optical'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'scouting', 'signaling', 'optical'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'oil_flask', ruleset: RulesetVersion.v2024), name: 'Oil (Flask)',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Used as fuel for lanterns (6 hrs) or splashed as a ranged attack (20 ft) to add 5 fire damage when ignited.',
      rules2014: ItemEditionDetails(
        summary:
            'Used as fuel for lanterns (6 hrs) or splashed as a ranged attack (20 ft) to add 5 fire damage when ignited.',
        description:
            'A clay flask containing 1 pint of combustible mineral oil.',
        activation: '1 Action',
        properties: [
          'Fuel: 6 hours in a lantern.',
          'Attack: Ranged improvised weapon (20 ft).',
          'Ignition: Deals 5 extra fire damage on hit from fire sources for 2 rounds.',
          'Weight: 1 lb.',
          'Cost: 1 sp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Used as fuel for lanterns (6 hrs) or splashed as a ranged attack (20 ft) to add 5 fire damage when ignited.',
        description:
            'A clay flask containing 1 pint of combustible mineral oil.',
        activation: '1 Action',
        properties: [
          'Fuel: 6 hours in a lantern.',
          'Attack: Ranged improvised weapon (20 ft).',
          'Ignition: Deals 5 extra fire damage on fire attacks.',
          'Weight: 1 lb.',
          'Cost: 1 sp.',
        ],
      ),
      tags: ['gear', 'fire', 'fuel', 'combat', 'utility'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'fire', 'fuel', 'combat', 'utility'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'paper_sheet', ruleset: RulesetVersion.v2024), name: 'Paper (One Sheet)',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'A single leaf of rag or wood pulp paper suitable for maps, letters, and rubbings.',
      rules2014: ItemEditionDetails(
        summary:
            'A single leaf of rag or wood pulp paper suitable for maps, letters, and rubbings.',
        description: 'Smooth pressed paper for scribing and drawing.',
        properties: [
          'Weight: negligible.',
          'Cost: 2 sp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'A single leaf of rag or wood pulp paper suitable for maps, letters, and rubbings.',
        description: 'Smooth pressed paper for scribing and drawing.',
        properties: [
          'Weight: negligible.',
          'Cost: 2 sp.',
        ],
      ),
      tags: ['gear', 'writing', 'maps', 'letters'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'writing', 'maps', 'letters'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'parchment_sheet', ruleset: RulesetVersion.v2024), name: 'Parchment (One Sheet)',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Treated animal skin parchment, durable and weather-resistant for magical scrolls and official edicts.',
      rules2014: ItemEditionDetails(
        summary:
            'Treated animal skin parchment, durable and weather-resistant for magical scrolls and official edicts.',
        description:
            'A durable sheet of scraped and treated calf or sheep vellum.',
        properties: [
          'Weight: negligible.',
          'Cost: 1 sp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Treated animal skin parchment, durable and weather-resistant for magical scrolls and official edicts.',
        description:
            'A durable sheet of scraped and treated calf or sheep vellum.',
        properties: [
          'Weight: negligible.',
          'Cost: 1 sp.',
        ],
      ),
      tags: ['gear', 'writing', 'scrolls', 'documents'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'writing', 'scrolls', 'documents'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'perfume_vial', ruleset: RulesetVersion.v2024), name: 'Perfume (Vial)',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Aromatic essential oils providing sweet fragrance to mask dungeon stench or impress nobility.',
      rules2014: ItemEditionDetails(
        summary:
            'Aromatic essential oils providing sweet fragrance to mask dungeon stench or impress nobility.',
        description:
            'A decorative cut-crystal vial of distilled floral essence.',
        properties: [
          'Weight: negligible.',
          'Cost: 5 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Aromatic essential oils providing sweet fragrance to mask dungeon stench or impress nobility.',
        description:
            'A decorative cut-crystal vial of distilled floral essence.',
        properties: [
          'Weight: negligible.',
          'Cost: 5 gp.',
        ],
      ),
      tags: ['gear', 'social', 'aristocracy'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'social', 'aristocracy'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'pick_miners', ruleset: RulesetVersion.v2024), name: 'Pick, Miner\'s',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Two-handed pick for breaking through subterranean rock, masonry, and mineral veins.',
      rules2014: ItemEditionDetails(
        summary:
            'Two-handed pick for breaking through subterranean rock, masonry, and mineral veins.',
        description: 'A heavy pointed iron pick head fitted to an ash haft.',
        properties: [
          'Weight: 10 lbs.',
          'Cost: 2 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Two-handed pick for breaking through subterranean rock, masonry, and mineral veins.',
        description: 'A heavy pointed iron pick head fitted to an ash haft.',
        properties: [
          'Weight: 10 lbs.',
          'Cost: 2 gp.',
        ],
      ),
      tags: ['gear', 'mining', 'tool', 'excavation', 'piercing'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'mining', 'tool', 'excavation', 'piercing'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'piton', ruleset: RulesetVersion.v2024), name: 'Piton',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Iron spike with an eyelet for passing rope through during climbing or spiking doors shut.',
      rules2014: ItemEditionDetails(
        summary:
            'Iron spike with an eyelet for passing rope through during climbing or spiking doors shut.',
        description:
            'A forged steel spike driven into rock crevices to create rope anchor points.',
        properties: [
          'Weight: ¼ lb.',
          'Cost: 5 cp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Iron spike with an eyelet for passing rope through during climbing or spiking doors shut.',
        description:
            'A forged steel spike driven into rock crevices to create rope anchor points.',
        properties: [
          'Weight: ¼ lb.',
          'Cost: 5 cp.',
        ],
      ),
      tags: ['gear', 'climbing', 'anchors', 'iron'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'climbing', 'anchors', 'iron'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'poison_basic', ruleset: RulesetVersion.v2024), name: 'Poison, Basic (Vial)',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Applied to one slashing/piercing weapon or up to 3 pieces of ammunition. Hit creature must succeed on DC 10 Constitution save or take 1d4 poison damage.',
      rules2014: ItemEditionDetails(
        summary:
            'Applied to one slashing/piercing weapon or up to 3 pieces of ammunition. Hit creature must succeed on DC 10 Constitution save or take 1d4 poison damage.',
        description:
            'A toxic extract of nightshade, hemlock, or serpent venom.',
        activation: '1 Action',
        properties: [
          'Coats 1 weapon or 3 ammunition pieces for 1 minute.',
          'DC 10 Constitution save or 1d4 poison damage on hit.',
          'Weight: negligible.',
          'Cost: 100 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Applied to one slashing/piercing weapon or up to 3 pieces of ammunition. Hit creature must succeed on DC 10 Constitution save or take 1d4 poison damage.',
        description:
            'A toxic extract of nightshade, hemlock, or serpent venom.',
        activation: '1 Action',
        properties: [
          'Coats 1 weapon or 3 ammunition pieces for 1 minute.',
          'DC 10 Constitution save or 1d4 poison damage.',
          'Weight: negligible.',
          'Cost: 100 gp.',
        ],
      ),
      tags: ['gear', 'poison', 'combat', 'coating'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'poison', 'combat', 'coating'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'pole_10ft', ruleset: RulesetVersion.v2024), name: 'Pole (10-Foot)',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'A 10-foot wooden pole used for probing suspicious floor tiles, testing water depth, and triggering pressure plates.',
      rules2014: ItemEditionDetails(
        summary:
            'A 10-foot wooden pole used for probing suspicious floor tiles, testing water depth, and triggering pressure plates.',
        description: 'The legendary dungeon-delver\'s ten-foot wooden pole.',
        properties: [
          'Length: 10 feet.',
          'Weight: 7 lbs.',
          'Cost: 5 cp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'A 10-foot wooden pole used for probing suspicious floor tiles, testing water depth, and triggering pressure plates.',
        description: 'The legendary dungeon-delver\'s ten-foot wooden pole.',
        properties: [
          'Length: 10 feet.',
          'Weight: 7 lbs.',
          'Cost: 5 cp.',
        ],
      ),
      tags: ['gear', 'traps', 'utility', 'dungeon'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'traps', 'utility', 'dungeon'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'ram_portable', ruleset: RulesetVersion.v2024), name: 'Ram, Portable',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Grants +4 bonus on Strength checks to break down doors. Another character can assist to grant Advantage.',
      rules2014: ItemEditionDetails(
        summary:
            'Grants +4 bonus on Strength checks to break down doors. Another character can assist to grant Advantage.',
        description:
            'An iron-shod timber beam fitted with handles for one or two persons.',
        properties: [
          '+4 bonus to Strength checks made to breach doors.',
          'Assisting helper grants Advantage.',
          'Weight: 35 lbs.',
          'Cost: 4 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Grants +4 bonus on Strength checks to break down doors. Another character can assist to grant Advantage.',
        description:
            'An iron-shod timber beam fitted with handles for one or two persons.',
        properties: [
          '+4 bonus to Strength checks made to breach doors.',
          'Weight: 35 lbs.',
          'Cost: 4 gp.',
        ],
      ),
      tags: ['gear', 'breaching', 'doors', 'demolition'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'breaching', 'doors', 'demolition'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'rations', ruleset: RulesetVersion.v2024), name: 'Rations (1 Day)',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Compact dry food suitable for extended travel, including jerky, dried fruit, hardtack, and nuts.',
      rules2014: ItemEditionDetails(
        summary:
            'Compact dry food suitable for extended travel, including jerky, dried fruit, hardtack, and nuts.',
        description:
            'One day\'s worth of preserved survival sustenance for a Medium creature.',
        properties: [
          'Weight: 2 lbs.',
          'Cost: 5 sp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Compact dry food suitable for extended travel, including jerky, dried fruit, hardtack, and nuts.',
        description:
            'One day\'s worth of preserved survival sustenance for a Medium creature.',
        properties: [
          'Weight: 2 lbs.',
          'Cost: 5 sp.',
        ],
      ),
      tags: ['gear', 'food', 'survival'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'food', 'survival'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'rope_hempen', ruleset: RulesetVersion.v2024), name: 'Rope, Hempen (50 Feet)',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: '50-foot natural hemp rope. Has 2 hit points and can be burst with a DC 17 Strength check.',
      rules2014: ItemEditionDetails(
        summary:
            '50-foot natural hemp rope. Has 2 hit points and can be burst with a DC 17 Strength check.',
        description:
            'Standard braided natural hemp cordage for all climbing, hauling, and binding needs.',
        properties: [
          'Length: 50 feet.',
          'HP: 2; Burst DC: 17 Strength.',
          'Weight: 10 lbs.',
          'Cost: 1 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            '50-foot natural hemp rope. Has 2 hit points and can be burst with a DC 17 Strength check.',
        description:
            'Standard braided natural hemp cordage for all climbing, hauling, and binding needs.',
        properties: [
          'Length: 50 feet.',
          'HP: 2; Burst DC: 17 Strength.',
          'Weight: 10 lbs.',
          'Cost: 1 gp.',
        ],
      ),
      tags: ['gear', 'rope', 'climbing', 'utility'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'rope', 'climbing', 'utility'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'rope_silk', ruleset: RulesetVersion.v2024), name: 'Rope, Silk (50 Feet)',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: '50-foot lightweight braided silk rope. Has 2 hit points and can be burst with a DC 17 Strength check.',
      rules2014: ItemEditionDetails(
        summary:
            '50-foot lightweight braided silk rope. Has 2 hit points and can be burst with a DC 17 Strength check.',
        description:
            'Strong, supple rope woven from spider or silkworm thread, much lighter than hempen rope.',
        properties: [
          'Length: 50 feet.',
          'HP: 2; Burst DC: 17 Strength.',
          'Weight: 5 lbs.',
          'Cost: 10 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            '50-foot lightweight braided silk rope. Has 2 hit points and can be burst with a DC 17 Strength check.',
        description:
            'Strong, supple rope woven from spider or silkworm thread, much lighter than hempen rope.',
        properties: [
          'Length: 50 feet.',
          'HP: 2; Burst DC: 17 Strength.',
          'Weight: 5 lbs.',
          'Cost: 10 gp.',
        ],
      ),
      tags: ['gear', 'utility', 'climbing', 'restraint'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'utility', 'climbing', 'restraint'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'scale_merchants', ruleset: RulesetVersion.v2024), name: 'Scale, Merchant\'s',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Balanced brass balance scale with precise counterweights for measuring precious metals and gems.',
      rules2014: ItemEditionDetails(
        summary:
            'Balanced brass balance scale with precise counterweights for measuring precious metals and gems.',
        description:
            'A calibrated balance scale essential for trade and banking.',
        properties: [
          'Weight: 3 lbs.',
          'Cost: 5 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Balanced brass balance scale with precise counterweights for measuring precious metals and gems.',
        description:
            'A calibrated balance scale essential for trade and banking.',
        properties: [
          'Weight: 3 lbs.',
          'Cost: 5 gp.',
        ],
      ),
      tags: ['gear', 'trade', 'measurement', 'coins'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'trade', 'measurement', 'coins'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'sealing_wax', ruleset: RulesetVersion.v2024), name: 'Sealing Wax',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Stick of red or black resin wax for sealing letters and identifying tampered documents.',
      rules2014: ItemEditionDetails(
        summary:
            'Stick of red or black resin wax for sealing letters and identifying tampered documents.',
        description:
            'High-adhesion wax melted by flame and impressed with a signet ring.',
        properties: [
          'Weight: negligible.',
          'Cost: 5 sp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Stick of red or black resin wax for sealing letters and identifying tampered documents.',
        description:
            'High-adhesion wax melted by flame and impressed with a signet ring.',
        properties: [
          'Weight: negligible.',
          'Cost: 5 sp.',
        ],
      ),
      tags: ['gear', 'writing', 'security', 'letters'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'writing', 'security', 'letters'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'shovel', ruleset: RulesetVersion.v2024), name: 'Shovel',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Sturdy steel-bladed spade with a wooden handle for digging trenches and unearthing burial vaults.',
      rules2014: ItemEditionDetails(
        summary:
            'Sturdy steel-bladed spade with a wooden handle for digging trenches and unearthing burial vaults.',
        description: 'A standard excavation tool.',
        properties: [
          'Weight: 5 lbs.',
          'Cost: 2 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Sturdy steel-bladed spade with a wooden handle for digging trenches and unearthing burial vaults.',
        description: 'A standard excavation tool.',
        properties: [
          'Weight: 5 lbs.',
          'Cost: 2 gp.',
        ],
      ),
      tags: ['gear', 'excavation', 'tool'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'excavation', 'tool'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'signal_whistle', ruleset: RulesetVersion.v2024), name: 'Signal Whistle',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Produces a piercing high-pitched blast audible up to a quarter mile away.',
      rules2014: ItemEditionDetails(
        summary:
            'Produces a piercing high-pitched blast audible up to a quarter mile away.',
        description: 'A small brass whistle on a neck lanyard.',
        properties: [
          'Weight: negligible.',
          'Cost: 5 cp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Produces a piercing high-pitched blast audible up to a quarter mile away.',
        description: 'A small brass whistle on a neck lanyard.',
        properties: [
          'Weight: negligible.',
          'Cost: 5 cp.',
        ],
      ),
      tags: ['gear', 'signaling', 'sound', 'scouting'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'signaling', 'sound', 'scouting'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'signet_ring', ruleset: RulesetVersion.v2024), name: 'Signet Ring',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Engraved with the heraldic crest of a noble house, guild, or sovereign order.',
      rules2014: ItemEditionDetails(
        summary:
            'Engraved with the heraldic crest of a noble house, guild, or sovereign order.',
        description:
            'A gold or silver ring with an intaglio crest for stamping heated sealing wax.',
        properties: [
          'Weight: negligible.',
          'Cost: 5 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Engraved with the heraldic crest of a noble house, guild, or sovereign order.',
        description:
            'A gold or silver ring with an intaglio crest for stamping heated sealing wax.',
        properties: [
          'Weight: negligible.',
          'Cost: 5 gp.',
        ],
      ),
      tags: ['gear', 'nobility', 'identification', 'letters'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'nobility', 'identification', 'letters'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'spellbook', ruleset: RulesetVersion.v2024), name: 'Spellbook',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Essential for wizards. A leather-bound tome holding 100 blank vellum pages for scribing spells.',
      rules2014: ItemEditionDetails(
        summary:
            'Essential for wizards. A leather-bound tome holding 100 blank vellum pages for scribing spells.',
        description:
            'A wizard\'s grimoire bound with protective metal corner-caps and a locking clasp.',
        properties: [
          'Holds 100 pages for spell transcription.',
          'Weight: 3 lbs.',
          'Cost: 50 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Essential for wizards. A leather-bound tome holding 100 blank vellum pages for scribing spells.',
        description:
            'A wizard\'s grimoire bound with protective metal corner-caps and a locking clasp.',
        properties: [
          'Holds 100 pages for spell transcription.',
          'Weight: 3 lbs.',
          'Cost: 50 gp.',
        ],
      ),
      tags: ['gear', 'wizard', 'arcane', 'spells', 'grimoire'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'wizard', 'arcane', 'spells', 'grimoire'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'spikes_iron', ruleset: RulesetVersion.v2024), name: 'Spikes, Iron (10)',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Ten heavy iron spikes for wedging dungeon doors open or closed and securing leverage points.',
      rules2014: ItemEditionDetails(
        summary:
            'Ten heavy iron spikes for wedging dungeon doors open or closed and securing leverage points.',
        description: 'Solid forged wedge spikes driven with a hammer.',
        properties: [
          'Weight: 5 lbs.',
          'Cost: 1 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Ten heavy iron spikes for wedging dungeon doors open or closed and securing leverage points.',
        description: 'Solid forged wedge spikes driven with a hammer.',
        properties: [
          'Weight: 5 lbs.',
          'Cost: 1 gp.',
        ],
      ),
      tags: ['gear', 'iron', 'dungeon', 'doors'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'iron', 'dungeon', 'doors'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'spyglass', ruleset: RulesetVersion.v2024), name: 'Spyglass',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Objects viewed through the spyglass are magnified to twice their size.',
      rules2014: ItemEditionDetails(
        summary:
            'Objects viewed through the spyglass are magnified to twice their size.',
        description:
            'A telescoping brass tube with polished glass lenses for naval navigation and long-range scouting.',
        properties: [
          '2x visual magnification.',
          'Weight: 1 lb.',
          'Cost: 1,000 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Objects viewed through the spyglass are magnified to twice their size.',
        description:
            'A telescoping brass tube with polished glass lenses for naval navigation and long-range scouting.',
        properties: [
          '2x visual magnification.',
          'Weight: 1 lb.',
          'Cost: 1,000 gp.',
        ],
      ),
      tags: ['gear', 'vision', 'scouting', 'optical'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'vision', 'scouting', 'optical'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'tent_two_person', ruleset: RulesetVersion.v2024), name: 'Tent, Two-Person',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'A canvas shelter with collapsible wooden poles and stakes, sleeping up to two Medium creatures.',
      rules2014: ItemEditionDetails(
        summary:
            'A canvas shelter with collapsible wooden poles and stakes, sleeping up to two Medium creatures.',
        description:
            'A weather-treated canvas tent providing shelter during long rests.',
        properties: [
          'Capacity: 2 Medium creatures.',
          'Weight: 20 lbs.',
          'Cost: 2 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'A canvas shelter with collapsible wooden poles and stakes, sleeping up to two Medium creatures.',
        description:
            'A weather-treated canvas tent providing shelter during long rests.',
        properties: [
          'Capacity: 2 Medium creatures.',
          'Weight: 20 lbs.',
          'Cost: 2 gp.',
        ],
      ),
      tags: ['gear', 'shelter', 'camp', 'survival'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'shelter', 'camp', 'survival'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'tinderbox', ruleset: RulesetVersion.v2024), name: 'Tinderbox',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Contains flint, fire steel, and dry tinder. Lighting a torch takes 1 action; lighting a campfire takes 1 minute.',
      rules2014: ItemEditionDetails(
        summary:
            'Contains flint, fire steel, and dry tinder. Lighting a torch takes 1 action; lighting a campfire takes 1 minute.',
        description:
            'A small metal box protecting dry shredded bark, charred linen, flint, and steel striker.',
        activation: '1 Action (torch) / 1 Minute (fire)',
        properties: [
          'Starts fires and torches.',
          'Weight: 1 lb.',
          'Cost: 5 sp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Contains flint, fire steel, and dry tinder. Lighting a torch takes 1 action; lighting a campfire takes 1 minute.',
        description:
            'A small metal box protecting dry shredded bark, charred linen, flint, and steel striker.',
        activation: '1 Action / 1 Minute',
        properties: [
          'Starts fires and torches.',
          'Weight: 1 lb.',
          'Cost: 5 sp.',
        ],
      ),
      tags: ['gear', 'fire', 'camp', 'utility'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'fire', 'camp', 'utility'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'torch', ruleset: RulesetVersion.v2024), name: 'Torch',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Burns for 1 hour, shedding bright light in a 20-foot radius and dim light for an additional 20 feet. Deals 1 fire damage on hit.',
      rules2014: ItemEditionDetails(
        summary:
            'Burns for 1 hour, shedding bright light in a 20-foot radius and dim light for an additional 20 feet. Deals 1 fire damage on hit.',
        description: 'A wooden rod wrapped in pitch-soaked cloth.',
        properties: [
          'Bright light: 20-ft radius; Dim light: additional 20 ft.',
          'Burns for 1 hour.',
          'Melee attack deals 1 fire damage.',
          'Weight: 1 lb.',
          'Cost: 1 cp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Burns for 1 hour, shedding bright light in a 20-foot radius and dim light for an additional 20 feet. Deals 1 fire damage on hit.',
        description: 'A wooden rod wrapped in pitch-soaked cloth.',
        properties: [
          'Bright light: 20-ft radius; Dim light: additional 20 ft.',
          'Burns for 1 hour.',
          'Melee attack deals 1 fire damage.',
          'Weight: 1 lb.',
          'Cost: 1 cp.',
        ],
      ),
      tags: ['gear', 'light', 'fire', 'exploration'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'light', 'fire', 'exploration'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'whetstone', ruleset: RulesetVersion.v2024), name: 'Whetstone',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Fine abrasive stone used to hone bladed weapons and remove burrs.',
      rules2014: ItemEditionDetails(
        summary:
            'Fine abrasive stone used to hone bladed weapons and remove burrs.',
        description: 'A dual-grit polishing stone for weapon edge maintenance.',
        properties: [
          'Weight: 1 lb.',
          'Cost: 1 cp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Fine abrasive stone used to hone bladed weapons and remove burrs.',
        description: 'A dual-grit polishing stone for weapon edge maintenance.',
        properties: [
          'Weight: 1 lb.',
          'Cost: 1 cp.',
        ],
      ),
      tags: ['gear', 'maintenance', 'weapons'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'maintenance', 'weapons'] },
    ),

    // =========================================================================
    // 3. CLOTHES & APPAREL
    // =========================================================================
    EquipmentItem(
      id: EntityId(slug: 'clothes_common', ruleset: RulesetVersion.v2024), name: 'Clothes, Common',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Simple peasant or working-class garments consisting of a tunic, breeches, and cloth wrap.',
      rules2014: ItemEditionDetails(
        summary:
            'Simple peasant or working-class garments consisting of a tunic, breeches, and cloth wrap.',
        description:
            'Homespun wool or linen clothing suitable for everyday farm or labor work.',
        properties: [
          'Weight: 3 lbs.',
          'Cost: 5 sp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Simple peasant or working-class garments consisting of a tunic, breeches, and cloth wrap.',
        description:
            'Homespun wool or linen clothing suitable for everyday farm or labor work.',
        properties: [
          'Weight: 3 lbs.',
          'Cost: 5 sp.',
        ],
      ),
      tags: ['gear', 'clothing', 'apparel'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'clothing', 'apparel'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'clothes_costume', ruleset: RulesetVersion.v2024), name: 'Clothes, Costume',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Theatrical clothing with vibrant colors, props, and exaggerated silhouettes for acting or disguise.',
      rules2014: ItemEditionDetails(
        summary:
            'Theatrical clothing with vibrant colors, props, and exaggerated silhouettes for acting or disguise.',
        description:
            'Costume attire designed for stage actors, jesters, and disguise infiltration.',
        properties: [
          'Weight: 4 lbs.',
          'Cost: 5 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Theatrical clothing with vibrant colors, props, and exaggerated silhouettes for acting or disguise.',
        description:
            'Costume attire designed for stage actors, jesters, and disguise infiltration.',
        properties: [
          'Weight: 4 lbs.',
          'Cost: 5 gp.',
        ],
      ),
      tags: ['gear', 'clothing', 'disguise', 'performance'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'clothing', 'disguise', 'performance'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'clothes_fine', ruleset: RulesetVersion.v2024), name: 'Clothes, Fine',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'High-fashion velvet, brocade, and silk apparel worn by aristocrats, diplomats, and wealthy merchants.',
      rules2014: ItemEditionDetails(
        summary:
            'High-fashion velvet, brocade, and silk apparel worn by aristocrats, diplomats, and wealthy merchants.',
        description:
            'Tailored courtier garments adorned with embroidery and subtle filigree.',
        properties: [
          'Weight: 6 lbs.',
          'Cost: 15 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'High-fashion velvet, brocade, and silk apparel worn by aristocrats, diplomats, and wealthy merchants.',
        description:
            'Tailored courtier garments adorned with embroidery and subtle filigree.',
        properties: [
          'Weight: 6 lbs.',
          'Cost: 15 gp.',
        ],
      ),
      tags: ['gear', 'clothing', 'aristocracy', 'social'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'clothing', 'aristocracy', 'social'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'clothes_travelers', ruleset: RulesetVersion.v2024), name: 'Clothes, Traveler\'s',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Sturdy leather-reinforced boots, wool cloak, tunic, and trousers designed for long journeys in varied weather.',
      rules2014: ItemEditionDetails(
        summary:
            'Sturdy leather-reinforced boots, wool cloak, tunic, and trousers designed for long journeys in varied weather.',
        description:
            'Comfortable, durable expedition wear resilient to trail mud and rain.',
        properties: [
          'Weight: 4 lbs.',
          'Cost: 2 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Sturdy leather-reinforced boots, wool cloak, tunic, and trousers designed for long journeys in varied weather.',
        description:
            'Comfortable, durable expedition wear resilient to trail mud and rain.',
        properties: [
          'Weight: 4 lbs.',
          'Cost: 2 gp.',
        ],
      ),
      tags: ['gear', 'clothing', 'travel', 'exploration'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'clothing', 'travel', 'exploration'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'robes', ruleset: RulesetVersion.v2024), name: 'Robes',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Flowing ceremonial or scholarly vestments favored by wizards, monks, and clergy.',
      rules2014: ItemEditionDetails(
        summary:
            'Flowing ceremonial or scholarly vestments favored by wizards, monks, and clergy.',
        description:
            'Floor-length cloth robes with deep cowl and wide sleeves.',
        properties: [
          'Weight: 4 lbs.',
          'Cost: 1 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Flowing ceremonial or scholarly vestments favored by wizards, monks, and clergy.',
        description:
            'Floor-length cloth robes with deep cowl and wide sleeves.',
        properties: [
          'Weight: 4 lbs.',
          'Cost: 1 gp.',
        ],
      ),
      tags: ['gear', 'clothing', 'arcane', 'divine'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['gear', 'clothing', 'arcane', 'divine'] },
    ),

    // =========================================================================
    // 4. SPELLCASTING FOCI
    // =========================================================================
    EquipmentItem(
      id: EntityId(slug: 'arcane_focus_wand', ruleset: RulesetVersion.v2024), name: 'Arcane Focus (Wand / Crystal / Orb)',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'A spellcasting focus designed to channel arcane spells, replacing non-costly material components.',
      rules2014: ItemEditionDetails(
        summary:
            'A special item designed to channel the power of arcane spells, substituting for non-costly material components.',
        description:
            'Crafted from crystal, orbs of glass, carved wands of weirwood, or polished rods.',
        properties: [
          'Substitutes for material components with no gp cost.',
          'Weight: 1–3 lbs.',
          'Cost: 5–20 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'A spellcasting focus designed to channel arcane spells, replacing non-costly material components.',
        description:
            'Crafted from crystal, orbs of glass, carved wands of weirwood, or polished rods.',
        properties: [
          'Substitutes for material components with no gp cost.',
          'Weight: 1–3 lbs.',
          'Cost: 5–20 gp.',
        ],
      ),
      tags: [
        'focus',
        'spellcasting',
        'arcane',
        'wizard',
        'sorcerer',
        'warlock'
      ],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['focus', 'spellcasting', 'arcane', 'wizard', 'sorcerer', 'warlock'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'holy_symbol_amulet', ruleset: RulesetVersion.v2024), name: 'Holy Symbol (Amulet / Emblem / Reliquary)',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'A representation of a deity or pantheon used as a divine spellcasting focus. Can be worn as an amulet or emblazoned on a shield.',
      rules2014: ItemEditionDetails(
        summary:
            'A representation of a deity or pantheon used as a divine spellcasting focus. Can be worn as an amulet or emblazoned on a shield.',
        description:
            'Consecrated icon, sunburst, or miniature reliquary honoring a divine power.',
        properties: [
          'Can be emblazoned on a shield or worn openly.',
          'Substitutes for non-costly divine material components.',
          'Weight: 1 lb.',
          'Cost: 5 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'A representation of a deity or pantheon used as a divine spellcasting focus. Can be worn as an amulet or emblazoned on a shield.',
        description:
            'Consecrated icon, sunburst, or miniature reliquary honoring a divine power.',
        properties: [
          'Can be emblazoned on a shield or worn openly.',
          'Substitutes for non-costly divine material components.',
          'Weight: 1 lb.',
          'Cost: 5 gp.',
        ],
      ),
      tags: ['focus', 'spellcasting', 'divine', 'cleric', 'paladin'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['focus', 'spellcasting', 'divine', 'cleric', 'paladin'] },
    ),

    // =========================================================================
    // 5. TOOLS & KITS
    // =========================================================================
    EquipmentItem(
      id: EntityId(slug: 'thieves_tools', ruleset: RulesetVersion.v2024), name: 'Thieves\' Tools',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Allows adding proficiency bonus to Dexterity checks made with thieves\' tools to pick locks or disarm traps. Uses DC rules specified in the 2024 equipment chapter.',
      rules2014: ItemEditionDetails(
        summary:
            'Allows adding proficiency bonus to ability checks made to disarm traps or pick mechanical locks.',
        description:
            'A set of lock picks, tension wrenches, small mirror, narrow file, and pliers in a folding leather case.',
        properties: [
          'Used for picking locks and disarming mechanical traps.',
          'Weight: 1 lb.',
          'Cost: 25 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Allows adding proficiency bonus to Dexterity checks made with thieves\' tools to pick locks or disarm traps. Uses DC rules specified in the 2024 equipment chapter.',
        description:
            'A set of lock picks, tension wrenches, small mirror, narrow file, and pliers in a folding leather case.',
        properties: [
          'Used for Pick Lock (Sleight of Hand) and Disarm Trap checks.',
          'Weight: 1 lb.',
          'Cost: 25 gp.',
        ],
      ),
      tags: ['tools', 'lockpicking', 'traps', 'dexterity'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['tools', 'lockpicking', 'traps', 'dexterity'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'alchemists_supplies', ruleset: RulesetVersion.v2024), name: 'Alchemist\'s Supplies',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Includes glass beakers, stirring rods, mortar and pestle, and common chemical reagents for brewing and identification.',
      rules2014: ItemEditionDetails(
        summary:
            'Includes glass beakers, stirring rods, mortar and pestle, and common chemical reagents for brewing and identification.',
        description:
            'A portable laboratory kit for synthesizing acids, alchemist\'s fire, and analyzing strange residues.',
        properties: [
          'Proficiency allows crafting alchemical items and identifying substances.',
          'Weight: 8 lbs.',
          'Cost: 50 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Includes glass beakers, stirring rods, mortar and pestle, and common chemical reagents for brewing and identification.',
        description:
            'A portable laboratory kit for synthesizing acids, alchemist\'s fire, and analyzing strange residues.',
        properties: [
          'Proficiency allows crafting alchemical items and identifying substances.',
          'Weight: 8 lbs.',
          'Cost: 50 gp.',
        ],
      ),
      tags: ['tools', 'crafting', 'alchemy', 'potions'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['tools', 'crafting', 'alchemy', 'potions'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'brewers_supplies', ruleset: RulesetVersion.v2024), name: 'Brewer\'s Supplies',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Includes a siphon, hydrometer, hops, yeast, and kegging tubes for fermenting beer, cider, and spirits.',
      rules2014: ItemEditionDetails(
        summary:
            'Includes a siphon, hydrometer, hops, yeast, and kegging tubes for fermenting beer, cider, and spirits.',
        description:
            'Equipment needed to brew quality ales, stouts, and purifying water supplies.',
        properties: [
          'Weight: 9 lbs.',
          'Cost: 20 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Includes a siphon, hydrometer, hops, yeast, and kegging tubes for fermenting beer, cider, and spirits.',
        description:
            'Equipment needed to brew quality ales, stouts, and purifying water supplies.',
        properties: [
          'Weight: 9 lbs.',
          'Cost: 20 gp.',
        ],
      ),
      tags: ['tools', 'crafting', 'brewing', 'food'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['tools', 'crafting', 'brewing', 'food'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'calligraphers_supplies', ruleset: RulesetVersion.v2024), name: 'Calligrapher\'s Supplies',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Specialized inks, gold leaf, varied nibs, and ruling stones for illuminating manuscripts and writing official scrolls.',
      rules2014: ItemEditionDetails(
        summary:
            'Specialized inks, gold leaf, varied nibs, and ruling stones for illuminating manuscripts and writing official scrolls.',
        description:
            'Precision writing implements for creating beautiful calligraphy and copying scrolls.',
        properties: [
          'Weight: 5 lbs.',
          'Cost: 10 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Specialized inks, gold leaf, varied nibs, and ruling stones for illuminating manuscripts and writing official scrolls.',
        description:
            'Precision writing implements for creating beautiful calligraphy and copying scrolls.',
        properties: [
          'Weight: 5 lbs.',
          'Cost: 10 gp.',
        ],
      ),
      tags: ['tools', 'writing', 'scrolls', 'artisan'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['tools', 'writing', 'scrolls', 'artisan'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'carpenters_tools', ruleset: RulesetVersion.v2024), name: 'Carpenter\'s Tools',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Includes a saw, hammer, nails, adze, square, plane, and chisel for woodworking and building structures.',
      rules2014: ItemEditionDetails(
        summary:
            'Includes a saw, hammer, nails, adze, square, plane, and chisel for woodworking and building structures.',
        description:
            'Essential kit for building barricades, bridges, doors, and timber repairs.',
        properties: [
          'Weight: 6 lbs.',
          'Cost: 8 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Includes a saw, hammer, nails, adze, square, plane, and chisel for woodworking and building structures.',
        description:
            'Essential kit for building barricades, bridges, doors, and timber repairs.',
        properties: [
          'Weight: 6 lbs.',
          'Cost: 8 gp.',
        ],
      ),
      tags: ['tools', 'crafting', 'woodworking', 'construction'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['tools', 'crafting', 'woodworking', 'construction'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'cartographers_tools', ruleset: RulesetVersion.v2024), name: 'Cartographer\'s Tools',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Compasses, fine calipers, inks, measuring cords, and parchment for drafting accurate dungeon and overland maps.',
      rules2014: ItemEditionDetails(
        summary:
            'Compasses, fine calipers, inks, measuring cords, and parchment for drafting accurate dungeon and overland maps.',
        description:
            'Precision mapping instruments for surveying unexplored territory.',
        properties: [
          'Weight: 6 lbs.',
          'Cost: 15 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Compasses, fine calipers, inks, measuring cords, and parchment for drafting accurate dungeon and overland maps.',
        description:
            'Precision mapping instruments for surveying unexplored territory.',
        properties: [
          'Weight: 6 lbs.',
          'Cost: 15 gp.',
        ],
      ),
      tags: ['tools', 'navigation', 'maps', 'exploration'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['tools', 'navigation', 'maps', 'exploration'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'cobblers_tools', ruleset: RulesetVersion.v2024), name: 'Cobbler\'s Tools',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Includes a cobbler\'s last, awl, leather knives, thread, and replacement heel soles.',
      rules2014: ItemEditionDetails(
        summary:
            'Includes a cobbler\'s last, awl, leather knives, thread, and replacement heel soles.',
        description:
            'Tools for repairing traveler\'s boots and crafting hidden boot-heel compartments.',
        properties: [
          'Weight: 5 lbs.',
          'Cost: 5 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Includes a cobbler\'s last, awl, leather knives, thread, and replacement heel soles.',
        description:
            'Tools for repairing traveler\'s boots and crafting hidden boot-heel compartments.',
        properties: [
          'Weight: 5 lbs.',
          'Cost: 5 gp.',
        ],
      ),
      tags: ['tools', 'crafting', 'leather', 'boots'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['tools', 'crafting', 'leather', 'boots'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'cooks_utensils', ruleset: RulesetVersion.v2024), name: 'Cook\'s Utensils',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Includes an iron pot, skillet, knives, seasoning vials, and stirring spoons for preparing nourishing meals.',
      rules2014: ItemEditionDetails(
        summary:
            'Includes an iron pot, skillet, knives, seasoning vials, and stirring spoons for preparing nourishing meals.',
        description:
            'Field cooking gear that turns foraged game into wholesome banquet meals during long rests.',
        properties: [
          'Weight: 8 lbs.',
          'Cost: 1 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Includes an iron pot, skillet, knives, seasoning vials, and stirring spoons for preparing nourishing meals.',
        description:
            'Field cooking gear that turns foraged game into wholesome banquet meals during long rests.',
        properties: [
          'Weight: 8 lbs.',
          'Cost: 1 gp.',
        ],
      ),
      tags: ['tools', 'cooking', 'survival', 'camp', 'sustain'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['tools', 'cooking', 'survival', 'camp', 'sustain'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'disguise_kit', ruleset: RulesetVersion.v2024), name: 'Disguise Kit',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Includes makeup, false hair, props, prosthetics, and costume jewelry for altering one\'s physical appearance.',
      rules2014: ItemEditionDetails(
        summary:
            'Includes makeup, false hair, props, prosthetics, and costume jewelry for altering one\'s physical appearance.',
        description:
            'Professional disguise cosmetics to impersonate guards, nobles, or commoners.',
        properties: [
          'Adds proficiency to checks made to create a visual disguise.',
          'Weight: 3 lbs.',
          'Cost: 25 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Includes makeup, false hair, props, prosthetics, and costume jewelry for altering one\'s physical appearance.',
        description:
            'Professional disguise cosmetics to impersonate guards, nobles, or commoners.',
        properties: [
          'Adds proficiency to checks made to create a visual disguise.',
          'Weight: 3 lbs.',
          'Cost: 25 gp.',
        ],
      ),
      tags: ['tools', 'deception', 'disguise', 'stealth'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['tools', 'deception', 'disguise', 'stealth'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'forgery_kit', ruleset: RulesetVersion.v2024), name: 'Forgery Kit',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Includes varied parchment blanks, specialty inks, wax seals, stamps, and fine pens for counterfeiting documents.',
      rules2014: ItemEditionDetails(
        summary:
            'Includes varied parchment blanks, specialty inks, wax seals, stamps, and fine pens for counterfeiting documents.',
        description:
            'A discreet case with chemicals and tools for faking royal passes and signatures.',
        properties: [
          'Weight: 5 lbs.',
          'Cost: 15 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Includes varied parchment blanks, specialty inks, wax seals, stamps, and fine pens for counterfeiting documents.',
        description:
            'A discreet case with chemicals and tools for faking royal passes and signatures.',
        properties: [
          'Weight: 5 lbs.',
          'Cost: 15 gp.',
        ],
      ),
      tags: ['tools', 'deception', 'forgery', 'documents'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['tools', 'deception', 'forgery', 'documents'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'gaming_set_dice', ruleset: RulesetVersion.v2024), name: 'Gaming Set (Dice Set / Playing Cards / Dragonchess)',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Dice, playing cards, Dragonchess, or Three-Dragon Ante set for gambling and passing camp downtime.',
      rules2014: ItemEditionDetails(
        summary:
            'Dice, playing cards, Dragonchess, or Three-Dragon Ante set for gambling and passing camp downtime.',
        description:
            'Recreational games popular across tavern halls and adventuring camps.',
        properties: [
          'Weight: negligible–½ lb.',
          'Cost: 1 sp–1 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Dice, playing cards, Dragonchess, or Three-Dragon Ante set for gambling and passing camp downtime.',
        description:
            'Recreational games popular across tavern halls and adventuring camps.',
        properties: [
          'Weight: negligible–½ lb.',
          'Cost: 1 sp–1 gp.',
        ],
      ),
      tags: ['tools', 'gaming', 'social', 'tavern'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['tools', 'gaming', 'social', 'tavern'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'glassblowers_tools', ruleset: RulesetVersion.v2024), name: 'Glassblower\'s Tools',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Includes a blowpipe, marver block, tongs, jacks, and shears for shaping molten glass into vials and lenses.',
      rules2014: ItemEditionDetails(
        summary:
            'Includes a blowpipe, marver block, tongs, jacks, and shears for shaping molten glass into vials and lenses.',
        description:
            'Equipment for crafting glass bottles, laboratory flasks, and optical mirrors.',
        properties: [
          'Weight: 5 lbs.',
          'Cost: 30 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Includes a blowpipe, marver block, tongs, jacks, and shears for shaping molten glass into vials and lenses.',
        description:
            'Equipment for crafting glass bottles, laboratory flasks, and optical mirrors.',
        properties: [
          'Weight: 5 lbs.',
          'Cost: 30 gp.',
        ],
      ),
      tags: ['tools', 'crafting', 'glass', 'artisan'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['tools', 'crafting', 'glass', 'artisan'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'herbalism_kit', ruleset: RulesetVersion.v2024), name: 'Herbalism Kit',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Includes pouches, clippers, mortar and pestle, and plant guides. Required for crafting Potions of Healing and Antitoxin.',
      rules2014: ItemEditionDetails(
        summary:
            'Includes pouches, clippers, mortar and pestle, and plant guides. Required for crafting Potions of Healing and Antitoxin.',
        description:
            'Essential field botany equipment for harvesting medicinal herbs in the wild.',
        properties: [
          'Required for crafting Antitoxins and Potions of Healing.',
          'Weight: 3 lbs.',
          'Cost: 5 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Includes pouches, clippers, mortar and pestle, and plant guides. Required for crafting Potions of Healing and Antitoxin.',
        description:
            'Essential field botany equipment for harvesting medicinal herbs in the wild.',
        properties: [
          'Required for crafting Antitoxins and Potions of Healing.',
          'Weight: 3 lbs.',
          'Cost: 5 gp.',
        ],
      ),
      tags: ['tools', 'herbalism', 'potions', 'healing', 'sustain'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['tools', 'herbalism', 'potions', 'healing', 'sustain'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'jewelers_tools', ruleset: RulesetVersion.v2024), name: 'Jeweler\'s Tools',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Includes small saws, files, pliers, tweezers, jeweler\'s loupe, and jewel clamps for gem-cutting and goldsmithing.',
      rules2014: ItemEditionDetails(
        summary:
            'Includes small saws, files, pliers, tweezers, jeweler\'s loupe, and jewel clamps for gem-cutting and goldsmithing.',
        description:
            'Precision gem-crafting instruments for setting precious stones and assessing jewel worth.',
        properties: [
          'Weight: 2 lbs.',
          'Cost: 25 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Includes small saws, files, pliers, tweezers, jeweler\'s loupe, and jewel clamps for gem-cutting and goldsmithing.',
        description:
            'Precision gem-crafting instruments for setting precious stones and assessing jewel worth.',
        properties: [
          'Weight: 2 lbs.',
          'Cost: 25 gp.',
        ],
      ),
      tags: ['tools', 'crafting', 'gems', 'jewelry'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['tools', 'crafting', 'gems', 'jewelry'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'leatherworkers_tools', ruleset: RulesetVersion.v2024), name: 'Leatherworker\'s Tools',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Includes leather knives, punches, groover, stitching needles, and burnishers for making and repairing leather armor and bags.',
      rules2014: ItemEditionDetails(
        summary:
            'Includes leather knives, punches, groover, stitching needles, and burnishers for making and repairing leather armor and bags.',
        description:
            'Crafting kit for tanning hides, tailoring leather armor, and saddlery.',
        properties: [
          'Weight: 5 lbs.',
          'Cost: 5 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Includes leather knives, punches, groover, stitching needles, and burnishers for making and repairing leather armor and bags.',
        description:
            'Crafting kit for tanning hides, tailoring leather armor, and saddlery.',
        properties: [
          'Weight: 5 lbs.',
          'Cost: 5 gp.',
        ],
      ),
      tags: ['tools', 'crafting', 'leather', 'armor'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['tools', 'crafting', 'leather', 'armor'], 'defaultSlot': EquipmentSlot.armor, 'baseAc': 11, 'armorType': 'light' },
    ),
    EquipmentItem(
      id: EntityId(slug: 'masons_tools', ruleset: RulesetVersion.v2024), name: 'Mason\'s Tools',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Includes a trowel, stone hammer, chisels, plumb line, and level for stonecarving and stone wall analysis.',
      rules2014: ItemEditionDetails(
        summary:
            'Includes a trowel, stone hammer, chisels, plumb line, and level for stonecarving and stone wall analysis.',
        description:
            'Tools for inspecting ancient stone architecture and carving masonry passages.',
        properties: [
          'Weight: 8 lbs.',
          'Cost: 10 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Includes a trowel, stone hammer, chisels, plumb line, and level for stonecarving and stone wall analysis.',
        description:
            'Tools for inspecting ancient stone architecture and carving masonry passages.',
        properties: [
          'Weight: 8 lbs.',
          'Cost: 10 gp.',
        ],
      ),
      tags: ['tools', 'crafting', 'stone', 'construction'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['tools', 'crafting', 'stone', 'construction'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'musical_instrument_lute', ruleset: RulesetVersion.v2024), name: 'Musical Instrument (Lute / Flute / Drum / Horn / Lyre / Bagpipes)',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Bards can use a musical instrument as a spellcasting focus for their bard spells.',
      rules2014: ItemEditionDetails(
        summary:
            'Bards can use a musical instrument as a spellcasting focus for their bard spells.',
        description:
            'Masterwork instrument crafted from cured tonewoods, brass, or stretched vellum.',
        properties: [
          'Serves as a spellcasting focus for Bards.',
          'Weight: 2–6 lbs.',
          'Cost: 2–35 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Bards can use a musical instrument as a spellcasting focus for their bard spells.',
        description:
            'Masterwork instrument crafted from cured tonewoods, brass, or stretched vellum.',
        properties: [
          'Serves as a spellcasting focus for Bards.',
          'Weight: 2–6 lbs.',
          'Cost: 2–35 gp.',
        ],
      ),
      tags: ['tools', 'bard', 'music', 'performance', 'focus'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['tools', 'bard', 'music', 'performance', 'focus'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'navigators_tools', ruleset: RulesetVersion.v2024), name: 'Navigator\'s Tools',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Includes a sextant, compass, calipers, astrolabe, and nautical charts for navigating on oceans and uncharted lands.',
      rules2014: ItemEditionDetails(
        summary:
            'Includes a sextant, compass, calipers, astrolabe, and nautical charts for navigating on oceans and uncharted lands.',
        description:
            'Essential navigational instruments for plotting coordinates by the sun and stars.',
        properties: [
          'Weight: 2 lbs.',
          'Cost: 25 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Includes a sextant, compass, calipers, astrolabe, and nautical charts for navigating on oceans and uncharted lands.',
        description:
            'Essential navigational instruments for plotting coordinates by the sun and stars.',
        properties: [
          'Weight: 2 lbs.',
          'Cost: 25 gp.',
        ],
      ),
      tags: ['tools', 'navigation', 'sea', 'exploration'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['tools', 'navigation', 'sea', 'exploration'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'painters_supplies', ruleset: RulesetVersion.v2024), name: 'Painter\'s Supplies',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Includes an easel, brushes, canvas panels, palette, and pigment jars for portraiture and landscape depiction.',
      rules2014: ItemEditionDetails(
        summary:
            'Includes an easel, brushes, canvas panels, palette, and pigment jars for portraiture and landscape depiction.',
        description:
            'Fine art supplies for copying visual depictions and capturing likenesses.',
        properties: [
          'Weight: 5 lbs.',
          'Cost: 10 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Includes an easel, brushes, canvas panels, palette, and pigment jars for portraiture and landscape depiction.',
        description:
            'Fine art supplies for copying visual depictions and capturing likenesses.',
        properties: [
          'Weight: 5 lbs.',
          'Cost: 10 gp.',
        ],
      ),
      tags: ['tools', 'crafting', 'art', 'canvas'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['tools', 'crafting', 'art', 'canvas'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'poisoners_kit', ruleset: RulesetVersion.v2024), name: 'Poisoner\'s Kit',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Includes glass vials, mortar and pestle, pipettes, and toxic plant/mineral extracts for brewing poisons safely.',
      rules2014: ItemEditionDetails(
        summary:
            'Includes glass vials, mortar and pestle, pipettes, and toxic plant/mineral extracts for brewing poisons safely.',
        description:
            'Specialized apparatus to distill venoms without poisoning oneself.',
        properties: [
          'Required for harvesting and brewing specialized poisons.',
          'Weight: 2 lbs.',
          'Cost: 50 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Includes glass vials, mortar and pestle, pipettes, and toxic plant/mineral extracts for brewing poisons safely.',
        description:
            'Specialized apparatus to distill venoms without poisoning oneself.',
        properties: [
          'Required for harvesting and brewing specialized poisons.',
          'Weight: 2 lbs.',
          'Cost: 50 gp.',
        ],
      ),
      tags: ['tools', 'poison', 'alchemy', 'stealth'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['tools', 'poison', 'alchemy', 'stealth'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'potters_tools', ruleset: RulesetVersion.v2024), name: 'Potter\'s Tools',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Includes potter\'s ribs, scrapers, wire clay cutter, and trimming loops for shaping pottery vessels.',
      rules2014: ItemEditionDetails(
        summary:
            'Includes potter\'s ribs, scrapers, wire clay cutter, and trimming loops for shaping pottery vessels.',
        description: 'Tools for sculpting ceramic urns, jugs, and amphorae.',
        properties: [
          'Weight: 3 lbs.',
          'Cost: 10 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Includes potter\'s ribs, scrapers, wire clay cutter, and trimming loops for shaping pottery vessels.',
        description: 'Tools for sculpting ceramic urns, jugs, and amphorae.',
        properties: [
          'Weight: 3 lbs.',
          'Cost: 10 gp.',
        ],
      ),
      tags: ['tools', 'crafting', 'clay', 'ceramic'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['tools', 'crafting', 'clay', 'ceramic'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'smiths_tools', ruleset: RulesetVersion.v2024), name: 'Smith\'s Tools',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Includes hammers, tongs, chisels, files, and aprons for forging and repairing metal weapons and armor at a forge.',
      rules2014: ItemEditionDetails(
        summary:
            'Includes hammers, tongs, chisels, files, and aprons for forging and repairing metal weapons and armor at a forge.',
        description:
            'Heavy forge implements for blacksmithing and weapon repair.',
        properties: [
          'Weight: 8 lbs.',
          'Cost: 20 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Includes hammers, tongs, chisels, files, and aprons for forging and repairing metal weapons and armor at a forge.',
        description:
            'Heavy forge implements for blacksmithing and weapon repair.',
        properties: [
          'Weight: 8 lbs.',
          'Cost: 20 gp.',
        ],
      ),
      tags: ['tools', 'crafting', 'blacksmithing', 'metal', 'weapons', 'armor'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['tools', 'crafting', 'blacksmithing', 'metal', 'weapons', 'armor'], 'defaultSlot': EquipmentSlot.armor },
    ),
    EquipmentItem(
      id: EntityId(slug: 'tinkers_tools', ruleset: RulesetVersion.v2024), name: 'Tinker\'s Tools',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Includes fine saws, pliers, solder, brazing tools, wire, and miniature gears for fixing small metal objects and clockwork.',
      rules2014: ItemEditionDetails(
        summary:
            'Includes fine saws, pliers, solder, brazing tools, wire, and miniature gears for fixing small metal objects and clockwork.',
        description:
            'A versatile toolkit for repairing lanterns, pots, hinges, and clockwork mechanisms.',
        properties: [
          'Weight: 10 lbs.',
          'Cost: 50 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Includes fine saws, pliers, solder, brazing tools, wire, and miniature gears for fixing small metal objects and clockwork.',
        description:
            'A versatile toolkit for repairing lanterns, pots, hinges, and clockwork mechanisms.',
        properties: [
          'Weight: 10 lbs.',
          'Cost: 50 gp.',
        ],
      ),
      tags: ['tools', 'crafting', 'repair', 'devices', 'clockwork'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['tools', 'crafting', 'repair', 'devices', 'clockwork'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'weavers_tools', ruleset: RulesetVersion.v2024), name: 'Weaver\'s Tools',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Includes shuttles, combs, scissors, needles, and a portable lap loom for weaving textiles and repairing tapestries.',
      rules2014: ItemEditionDetails(
        summary:
            'Includes shuttles, combs, scissors, needles, and a portable lap loom for weaving textiles and repairing tapestries.',
        description:
            'Equipment for spinning yarn and repairing cloaks, ropes, and tents.',
        properties: [
          'Weight: 5 lbs.',
          'Cost: 1 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Includes shuttles, combs, scissors, needles, and a portable lap loom for weaving textiles and repairing tapestries.',
        description:
            'Equipment for spinning yarn and repairing cloaks, ropes, and tents.',
        properties: [
          'Weight: 5 lbs.',
          'Cost: 1 gp.',
        ],
      ),
      tags: ['tools', 'crafting', 'textiles', 'cloth'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['tools', 'crafting', 'textiles', 'cloth'] },
    ),
    EquipmentItem(
      id: EntityId(slug: 'woodcarvers_tools', ruleset: RulesetVersion.v2024), name: 'Woodcarver\'s Tools',
      itemType: 'adventuringGear', category: ItemCategory.adventuringGear, rarity: 'nonmagical', rarityTier: ItemRarity.nonmagical,
      requiresAttunement: false,
      descriptionMarkdown: 'Includes whittling knives, gouges, rasps, and sandpaper for carving wooden icons, wands, and crafting arrows.',
      rules2014: ItemEditionDetails(
        summary:
            'Includes whittling knives, gouges, rasps, and sandpaper for carving wooden icons, wands, and crafting arrows.',
        description:
            'Precision carving knives for crafting arrows, arcane foci, and figurines.',
        properties: [
          'Weight: 5 lbs.',
          'Cost: 1 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary:
            'Includes whittling knives, gouges, rasps, and sandpaper for carving wooden icons, wands, and crafting arrows.',
        description:
            'Precision carving knives for crafting arrows, arcane foci, and figurines.',
        properties: [
          'Weight: 5 lbs.',
          'Cost: 1 gp.',
        ],
      ),
      tags: ['tools', 'crafting', 'woodcarving', 'arrows', 'wands'],
      customProperties: { 'cost': null, 'category': 'adventuringGear', 'tags': ['tools', 'crafting', 'woodcarving', 'arrows', 'wands'] },
    ),
  ];
}
