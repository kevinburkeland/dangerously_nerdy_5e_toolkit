import '../magic_item_data.dart';

/// Complete catalog of canonical SRD 5.1 / 5.2 nonmagical adventuring gear, equipment, and tools.
class SrdAdventuringGear {
  static const List<MagicItem> items = [
    // =========================================================================
    // 1. CONTAINERS & STORAGE
    // =========================================================================
    MagicItem(
      id: 'backpack',
      name: 'Backpack',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'container', 'storage', 'equipment'],
      rules2014: ItemEditionDetails(
        summary: 'Holds 1 cubic foot or 30 pounds of gear. You can strap items like a bedroll or rope to the outside.',
        description: 'A standard leather or canvas backpack designed for carrying adventuring supplies across dungeons and wilderness.',
        properties: [
          'Capacity: 1 cubic foot / 30 pounds.',
          'Weight: 5 lbs.',
          'Cost: 2 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Holds 1 cubic foot or 30 pounds of gear. You can strap items like a bedroll or rope to the outside.',
        description: 'A standard leather or canvas backpack designed for carrying adventuring supplies across dungeons and wilderness.',
        properties: [
          'Capacity: 1 cubic foot / 30 pounds.',
          'Weight: 5 lbs.',
          'Cost: 2 gp.',
        ],
      ),
    ),
    MagicItem(
      id: 'barrel',
      name: 'Barrel',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'container', 'storage', 'liquid'],
      rules2014: ItemEditionDetails(
        summary: 'Holds 40 gallons of liquid or 4 cubic feet of solid cargo.',
        description: 'A sturdy wooden cask bound with iron hoops, used for transporting ale, water, oil, and foodstuffs.',
        properties: [
          'Capacity: 40 gallons liquid / 4 cubic feet solid.',
          'Weight: 70 lbs.',
          'Cost: 2 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Holds 40 gallons of liquid or 4 cubic feet of solid cargo.',
        description: 'A sturdy wooden cask bound with iron hoops, used for transporting ale, water, oil, and foodstuffs.',
        properties: [
          'Capacity: 40 gallons liquid / 4 cubic feet solid.',
          'Weight: 70 lbs.',
          'Cost: 2 gp.',
        ],
      ),
    ),
    MagicItem(
      id: 'basket',
      name: 'Basket',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'container', 'storage'],
      rules2014: ItemEditionDetails(
        summary: 'Holds 2 cubic feet or 40 pounds of gear.',
        description: 'A woven wicker or reed basket with sturdy handles for foraging and marketplace provisioning.',
        properties: [
          'Capacity: 2 cubic feet / 40 pounds.',
          'Weight: 2 lbs.',
          'Cost: 4 sp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Holds 2 cubic feet or 40 pounds of gear.',
        description: 'A woven wicker or reed basket with sturdy handles for foraging and marketplace provisioning.',
        properties: [
          'Capacity: 2 cubic feet / 40 pounds.',
          'Weight: 2 lbs.',
          'Cost: 4 sp.',
        ],
      ),
    ),
    MagicItem(
      id: 'bottle_glass',
      name: 'Bottle, Glass',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'container', 'liquid'],
      rules2014: ItemEditionDetails(
        summary: 'Holds 1½ pints of liquid, corked with wax-sealed stopper.',
        description: 'A thick glass bottle suitable for storing wine, potions, distilled essences, or holy reagents.',
        properties: [
          'Capacity: 1½ pints liquid.',
          'Weight: 2 lbs.',
          'Cost: 2 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Holds 1½ pints of liquid, corked with wax-sealed stopper.',
        description: 'A thick glass bottle suitable for storing wine, potions, distilled essences, or holy reagents.',
        properties: [
          'Capacity: 1½ pints liquid.',
          'Weight: 2 lbs.',
          'Cost: 2 gp.',
        ],
      ),
    ),
    MagicItem(
      id: 'bucket',
      name: 'Bucket',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'container', 'liquid', 'utility'],
      rules2014: ItemEditionDetails(
        summary: 'Holds 3 gallons of liquid or ½ cubic foot of solid matter.',
        description: 'A wooden pail with a rope or metal bail handle for drawing water and clearing bilges.',
        properties: [
          'Capacity: 3 gallons liquid / ½ cubic foot.',
          'Weight: 2 lbs.',
          'Cost: 5 cp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Holds 3 gallons of liquid or ½ cubic foot of solid matter.',
        description: 'A wooden pail with a rope or metal bail handle for drawing water and clearing bilges.',
        properties: [
          'Capacity: 3 gallons liquid / ½ cubic foot.',
          'Weight: 2 lbs.',
          'Cost: 5 cp.',
        ],
      ),
    ),
    MagicItem(
      id: 'case_crossbow_bolt',
      name: 'Case, Crossbow Bolt',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'container', 'ammunition'],
      rules2014: ItemEditionDetails(
        summary: 'Holds up to 20 crossbow bolts securely in a rigid leather container.',
        description: 'A hard-molded leather cylindrical case with a snug cap to protect bolts from moisture and damage.',
        properties: [
          'Capacity: 20 bolts.',
          'Weight: 1 lb.',
          'Cost: 1 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Holds up to 20 crossbow bolts securely in a rigid leather container.',
        description: 'A hard-molded leather cylindrical case with a snug cap to protect bolts from moisture and damage.',
        properties: [
          'Capacity: 20 bolts.',
          'Weight: 1 lb.',
          'Cost: 1 gp.',
        ],
      ),
    ),
    MagicItem(
      id: 'case_map_scroll',
      name: 'Case, Map or Scroll',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'container', 'scrolls', 'maps'],
      rules2014: ItemEditionDetails(
        summary: 'Holds up to 10 rolled-up sheets of paper or 5 rolled-up sheets of parchment.',
        description: 'A watertight cylindrical leather or wooden tube with a screw cap for safeguarding documents.',
        properties: [
          'Capacity: 10 rolled paper or 5 parchment sheets.',
          'Weight: 1 lb.',
          'Cost: 1 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Holds up to 10 rolled-up sheets of paper or 5 rolled-up sheets of parchment.',
        description: 'A watertight cylindrical leather or wooden tube with a screw cap for safeguarding documents.',
        properties: [
          'Capacity: 10 rolled paper or 5 parchment sheets.',
          'Weight: 1 lb.',
          'Cost: 1 gp.',
        ],
      ),
    ),
    MagicItem(
      id: 'chest',
      name: 'Chest',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'container', 'storage', 'heavy'],
      rules2014: ItemEditionDetails(
        summary: 'Holds 12 cubic feet or 300 pounds of gear. Reinforced with iron bands.',
        description: 'A heavy wooden chest with iron corners, hasp, and side handles for secure dungeon and camp storage.',
        properties: [
          'Capacity: 12 cubic feet / 300 pounds.',
          'Weight: 25 lbs.',
          'Cost: 5 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Holds 12 cubic feet or 300 pounds of gear. Reinforced with iron bands.',
        description: 'A heavy wooden chest with iron corners, hasp, and side handles for secure dungeon and camp storage.',
        properties: [
          'Capacity: 12 cubic feet / 300 pounds.',
          'Weight: 25 lbs.',
          'Cost: 5 gp.',
        ],
      ),
    ),
    MagicItem(
      id: 'flask_tankard',
      name: 'Flask or Tankard',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'container', 'liquid'],
      rules2014: ItemEditionDetails(
        summary: 'Holds 1 pint of liquid.',
        description: 'A pewter, leather, or ceramic vessel for tavern drinking or pocket carriage of spirits.',
        properties: [
          'Capacity: 1 pint liquid.',
          'Weight: 1 lb.',
          'Cost: 2 cp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Holds 1 pint of liquid.',
        description: 'A pewter, leather, or ceramic vessel for tavern drinking or pocket carriage of spirits.',
        properties: [
          'Capacity: 1 pint liquid.',
          'Weight: 1 lb.',
          'Cost: 2 cp.',
        ],
      ),
    ),
    MagicItem(
      id: 'jug_pitcher',
      name: 'Jug or Pitcher',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'container', 'liquid'],
      rules2014: ItemEditionDetails(
        summary: 'Holds 1 gallon of liquid.',
        description: 'A ceramic or earthen jug with a narrow neck and handle for serving water, wine, or oil.',
        properties: [
          'Capacity: 1 gallon liquid.',
          'Weight: 4 lbs.',
          'Cost: 2 cp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Holds 1 gallon of liquid.',
        description: 'A ceramic or earthen jug with a narrow neck and handle for serving water, wine, or oil.',
        properties: [
          'Capacity: 1 gallon liquid.',
          'Weight: 4 lbs.',
          'Cost: 2 cp.',
        ],
      ),
    ),
    MagicItem(
      id: 'pot_iron',
      name: 'Pot, Iron',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'container', 'cooking', 'utility'],
      rules2014: ItemEditionDetails(
        summary: 'Holds 1 gallon of liquid for campfire cooking and boiling water.',
        description: 'A heavy cast-iron cooking vessel with a lid and hanging handle.',
        properties: [
          'Capacity: 1 gallon.',
          'Weight: 10 lbs.',
          'Cost: 2 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Holds 1 gallon of liquid for campfire cooking and boiling water.',
        description: 'A heavy cast-iron cooking vessel with a lid and hanging handle.',
        properties: [
          'Capacity: 1 gallon.',
          'Weight: 10 lbs.',
          'Cost: 2 gp.',
        ],
      ),
    ),
    MagicItem(
      id: 'pouch',
      name: 'Pouch',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'container', 'storage', 'coins'],
      rules2014: ItemEditionDetails(
        summary: 'Holds ⅕ cubic foot or up to 6 pounds of small items or coins (approx. 300 coins).',
        description: 'A cloth or leather pouch that fastens with a drawstring and secures to a belt.',
        properties: [
          'Capacity: ⅕ cubic foot / 6 lbs / 300 coins.',
          'Weight: 1 lb.',
          'Cost: 5 sp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Holds ⅕ cubic foot or up to 6 pounds of small items or coins (approx. 300 coins).',
        description: 'A cloth or leather pouch that fastens with a drawstring and secures to a belt.',
        properties: [
          'Capacity: ⅕ cubic foot / 6 lbs / 300 coins.',
          'Weight: 1 lb.',
          'Cost: 5 sp.',
        ],
      ),
    ),
    MagicItem(
      id: 'quiver',
      name: 'Quiver',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'container', 'ammunition', 'bow'],
      rules2014: ItemEditionDetails(
        summary: 'Holds up to 20 arrows comfortably over the shoulder or on the hip.',
        description: 'A leather case contoured to allow quick draw of archery arrows in combat.',
        properties: [
          'Capacity: 20 arrows.',
          'Weight: 1 lb.',
          'Cost: 1 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Holds up to 20 arrows comfortably over the shoulder or on the hip.',
        description: 'A leather case contoured to allow quick draw of archery arrows in combat.',
        properties: [
          'Capacity: 20 arrows.',
          'Weight: 1 lb.',
          'Cost: 1 gp.',
        ],
      ),
    ),
    MagicItem(
      id: 'sack',
      name: 'Sack',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'container', 'storage'],
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
    ),
    MagicItem(
      id: 'vial',
      name: 'Vial',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'container', 'liquid'],
      rules2014: ItemEditionDetails(
        summary: 'Holds up to 4 ounces of liquid, suitable for poisons, acids, or holy water.',
        description: 'A small glass or crystal cylindrical tube with a wax seal.',
        properties: [
          'Capacity: 4 fluid ounces.',
          'Weight: negligible.',
          'Cost: 1 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Holds up to 4 ounces of liquid, suitable for poisons, acids, or holy water.',
        description: 'A small glass or crystal cylindrical tube with a wax seal.',
        properties: [
          'Capacity: 4 fluid ounces.',
          'Weight: negligible.',
          'Cost: 1 gp.',
        ],
      ),
    ),
    MagicItem(
      id: 'waterskin',
      name: 'Waterskin',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'container', 'survival'],
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
    ),

    // =========================================================================
    // 2. ADVENTURING UTILITY, SURVIVAL & EXPLORATION
    // =========================================================================
    MagicItem(
      id: 'abacus',
      name: 'Abacus',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'calculation', 'mercantile'],
      rules2014: ItemEditionDetails(
        summary: 'Standard wooden counting frame with beads for rapid bookkeeping and mathematical calculation.',
        description: 'A framed calculating device widely used by merchants, tax collectors, and scholars.',
        properties: [
          'Weight: 2 lbs.',
          'Cost: 2 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Standard wooden counting frame with beads for rapid bookkeeping and mathematical calculation.',
        description: 'A framed calculating device widely used by merchants, tax collectors, and scholars.',
        properties: [
          'Weight: 2 lbs.',
          'Cost: 2 gp.',
        ],
      ),
    ),
    MagicItem(
      id: 'acid_vial',
      name: 'Acid (Vial)',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'acid', 'corrosive', 'combat', 'utility'],
      damageAccent: DamageAccent.acid,
      rules2014: ItemEditionDetails(
        summary: 'Improvised ranged attack (range 20 ft). On hit, deals 2d6 acid damage.',
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
        summary: 'Improvised ranged attack (range 20 ft). On hit, deals 2d6 acid damage.',
        description: 'A concentrated vial of highly caustic dissolving acid.',
        activation: '1 Action',
        properties: [
          'Ranged Improvised Weapon (20 ft).',
          'Deals 2d6 acid damage on hit.',
          'Weight: 1 lb.',
          'Cost: 25 gp.',
        ],
      ),
    ),
    MagicItem(
      id: 'alchemists_fire',
      name: 'Alchemist\'s Fire (Flask)',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'fire', 'combustible', 'combat'],
      damageAccent: DamageAccent.fire,
      rules2014: ItemEditionDetails(
        summary: 'Ranged attack (20 ft). On hit, target takes 1d4 fire damage at start of each of its turns until extinguished with a DC 10 Dex check.',
        description: 'A volatile sticky fluid that ignites when exposed to air.',
        activation: '1 Action',
        properties: [
          'Ranged Improvised Weapon (20 ft).',
          '1d4 fire damage at turn start until DC 10 Dexterity action extinguishes.',
          'Weight: 1 lb.',
          'Cost: 50 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Ranged attack (20 ft). On hit, target takes 1d4 fire damage at start of each turn until extinguished with a DC 10 Dex check.',
        description: 'A volatile sticky fluid that ignites when exposed to air.',
        activation: '1 Action',
        properties: [
          'Ranged Improvised Weapon (20 ft).',
          '1d4 fire damage per turn until put out.',
          'Weight: 1 lb.',
          'Cost: 50 gp.',
        ],
      ),
    ),
    MagicItem(
      id: 'antitoxin',
      name: 'Antitoxin (Vial)',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'poison', 'medicine', 'defense'],
      damageAccent: DamageAccent.poison,
      rules2014: ItemEditionDetails(
        summary: 'Drinking this provides Advantage on saving throws against poison for 1 hour.',
        description: 'A bitter herbal distillation that neutralizes toxins and venom.',
        activation: '1 Action',
        properties: [
          'Advantage on saving throws against poison for 1 hour.',
          'Weight: negligible.',
          'Cost: 50 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Drinking this provides Advantage on saving throws against poison for 1 hour.',
        description: 'A bitter herbal distillation that neutralizes toxins and venom.',
        activation: '1 Action',
        properties: [
          'Advantage on saving throws against poison for 1 hour.',
          'Weight: negligible.',
          'Cost: 50 gp.',
        ],
      ),
    ),
    MagicItem(
      id: 'ball_bearings',
      name: 'Ball Bearings (Bag of 1,000)',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'hazard', 'control', 'prone'],
      rules2014: ItemEditionDetails(
        summary: 'Cover a 10-foot square. Moving through at normal speed requires a DC 10 Dexterity save or fall Prone.',
        description: 'A pouch of 1,000 miniature metal spheres to create slick hazards.',
        activation: '1 Action',
        properties: [
          'Covers 10-foot square area.',
          'DC 10 Dexterity saving throw or fall Prone.',
          'Weight: 2 lbs.',
          'Cost: 1 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Cover a 10-foot square. Moving through at normal speed requires a DC 10 Dexterity save or fall Prone.',
        description: 'A pouch of 1,000 miniature metal spheres to create slick hazards.',
        activation: '1 Action',
        properties: [
          'Covers 10-foot square area.',
          'DC 10 Dexterity saving throw or fall Prone.',
          'Weight: 2 lbs.',
          'Cost: 1 gp.',
        ],
      ),
    ),
    MagicItem(
      id: 'bedroll',
      name: 'Bedroll',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'camp', 'rest', 'equipment'],
      rules2014: ItemEditionDetails(
        summary: 'Comfortable padded sleeping roll for taking short and long rests in the wild.',
        description: 'A quilted blanket and waterproof ground cloth rolled together with leather straps.',
        properties: [
          'Weight: 7 lbs.',
          'Cost: 1 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Comfortable padded sleeping roll for taking short and long rests in the wild.',
        description: 'A quilted blanket and waterproof ground cloth rolled together with leather straps.',
        properties: [
          'Weight: 7 lbs.',
          'Cost: 1 gp.',
        ],
      ),
    ),
    MagicItem(
      id: 'bell',
      name: 'Bell',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'alarm', 'signal', 'sound'],
      rules2014: ItemEditionDetails(
        summary: 'Small brass bell used for tripwire traps, camp alarms, or summoning calls.',
        description: 'A resonant metal bell that rings cleanly across quiet dungeon corridors.',
        properties: [
          'Weight: negligible.',
          'Cost: 1 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Small brass bell used for tripwire traps, camp alarms, or summoning calls.',
        description: 'A resonant metal bell that rings cleanly across quiet dungeon corridors.',
        properties: [
          'Weight: negligible.',
          'Cost: 1 gp.',
        ],
      ),
    ),
    MagicItem(
      id: 'blanket',
      name: 'Blanket',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'warmth', 'camp', 'survival'],
      rules2014: ItemEditionDetails(
        summary: 'Thick woven wool blanket for insulation against hypothermia and cold environments.',
        description: 'A durable wool blanket providing warmth during harsh wilderness expeditions.',
        properties: [
          'Weight: 3 lbs.',
          'Cost: 5 sp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Thick woven wool blanket for insulation against hypothermia and cold environments.',
        description: 'A durable wool blanket providing warmth during harsh wilderness expeditions.',
        properties: [
          'Weight: 3 lbs.',
          'Cost: 5 sp.',
        ],
      ),
    ),
    MagicItem(
      id: 'block_and_tackle',
      name: 'Block and Tackle',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'utility', 'lifting', 'engineering'],
      rules2014: ItemEditionDetails(
        summary: 'Pulleys and tackle allowing a creature to hoist up to 4 times the weight it can normally lift.',
        description: 'A system of grooved wheels and cable blocks for heavy architectural and salvage work.',
        properties: [
          'Multiplies lifting capacity by 4.',
          'Weight: 5 lbs.',
          'Cost: 1 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Pulleys and tackle allowing a creature to hoist up to 4 times the weight it can normally lift.',
        description: 'A system of grooved wheels and cable blocks for heavy architectural and salvage work.',
        properties: [
          'Multiplies lifting capacity by 4.',
          'Weight: 5 lbs.',
          'Cost: 1 gp.',
        ],
      ),
    ),
    MagicItem(
      id: 'book',
      name: 'Book',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'scholarship', 'history', 'lore'],
      rules2014: ItemEditionDetails(
        summary: 'A bound volume containing poetry, history, religious scriptures, or technical treatises.',
        description: 'A leather-bound folio containing illuminated parchment or paper pages.',
        properties: [
          'Weight: 5 lbs.',
          'Cost: 25 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'A bound volume containing poetry, history, religious scriptures, or technical treatises.',
        description: 'A leather-bound folio containing illuminated parchment or paper pages.',
        properties: [
          'Weight: 5 lbs.',
          'Cost: 25 gp.',
        ],
      ),
    ),
    MagicItem(
      id: 'caltrops',
      name: 'Caltrops (Bag of 20)',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'hazard', 'control', 'piercing'],
      damageAccent: DamageAccent.piercing,
      rules2014: ItemEditionDetails(
        summary: 'Covers a 5-foot square. Entering creature must succeed on DC 15 Dex save or take 1 piercing damage and speed reduced by 10 ft until healed.',
        description: 'A bag of 20 four-spiked iron caltrops that always land with one point upward.',
        activation: '1 Action',
        properties: [
          'Covers 5-foot square.',
          'DC 15 Dexterity save or 1 piercing damage and -10 ft Speed until HP regained.',
          'Weight: 2 lbs.',
          'Cost: 1 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Covers a 5-foot square. Entering creature must succeed on DC 15 Dex save or take 1 piercing damage and speed reduced by 10 ft until healed.',
        description: 'A bag of 20 four-spiked iron caltrops that always land with one point upward.',
        activation: '1 Action',
        properties: [
          'Covers 5-foot square.',
          'DC 15 Dexterity save or 1 piercing damage and -10 ft Speed.',
          'Weight: 2 lbs.',
          'Cost: 1 gp.',
        ],
      ),
    ),
    MagicItem(
      id: 'candle',
      name: 'Candle',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'light', 'fire', 'utility'],
      damageAccent: DamageAccent.fire,
      rules2014: ItemEditionDetails(
        summary: 'Burns for 1 hour, shedding bright light in a 5-foot radius and dim light for an additional 5 feet.',
        description: 'A standard tallow or beeswax candle.',
        properties: [
          'Bright light: 5-ft radius; Dim light: additional 5 ft.',
          'Burns for 1 hour.',
          'Weight: negligible.',
          'Cost: 1 cp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Burns for 1 hour, shedding bright light in a 5-foot radius and dim light for an additional 5 feet.',
        description: 'A standard tallow or beeswax candle.',
        properties: [
          'Bright light: 5-ft radius; Dim light: additional 5 ft.',
          'Burns for 1 hour.',
          'Weight: negligible.',
          'Cost: 1 cp.',
        ],
      ),
    ),
    MagicItem(
      id: 'chain_10ft',
      name: 'Chain (10 Feet)',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'restraint', 'utility', 'metal'],
      rules2014: ItemEditionDetails(
        summary: '10-foot iron chain. Has AC 19, 10 hit points, and burst DC 20 Strength.',
        description: 'Heavy welded iron links used to bind prisoners, secure portcullises, and anchor vehicles.',
        properties: [
          'AC: 19; HP: 10; Burst DC: 20 Strength.',
          'Weight: 10 lbs.',
          'Cost: 5 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: '10-foot iron chain. Has AC 19, 10 hit points, and burst DC 20 Strength.',
        description: 'Heavy welded iron links used to bind prisoners, secure portcullises, and anchor vehicles.',
        properties: [
          'AC: 19; HP: 10; Burst DC: 20 Strength.',
          'Weight: 10 lbs.',
          'Cost: 5 gp.',
        ],
      ),
    ),
    MagicItem(
      id: 'chalk',
      name: 'Chalk (1 Piece)',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'marking', 'navigation', 'utility'],
      rules2014: ItemEditionDetails(
        summary: 'Used to draw symbols, directional markers, and dungeon path codes on stone and wood.',
        description: 'A stick of soft limestone or calcium carbonate.',
        properties: [
          'Weight: negligible.',
          'Cost: 1 cp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Used to draw symbols, directional markers, and dungeon path codes on stone and wood.',
        description: 'A stick of soft limestone or calcium carbonate.',
        properties: [
          'Weight: negligible.',
          'Cost: 1 cp.',
        ],
      ),
    ),
    MagicItem(
      id: 'climbers_kit',
      name: 'Climber\'s Kit',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'climbing', 'safety', 'harness'],
      rules2014: ItemEditionDetails(
        summary: 'Includes pitons, boot tips, gloves, and harness. Allows anchoring oneself so a fall drops no more than 25 feet.',
        description: 'Specialized ascender gear and safety anchors for scaling sheer cliff faces.',
        properties: [
          'Prevents falling more than 25 feet while anchored.',
          'Weight: 12 lbs.',
          'Cost: 25 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Includes pitons, boot tips, gloves, and harness. Allows anchoring oneself so a fall drops no more than 25 feet.',
        description: 'Specialized ascender gear and safety anchors for scaling sheer cliff faces.',
        properties: [
          'Prevents falling more than 25 feet while anchored.',
          'Weight: 12 lbs.',
          'Cost: 25 gp.',
        ],
      ),
    ),
    MagicItem(
      id: 'component_pouch',
      name: 'Component Pouch',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'spellcasting', 'arcane', 'divine', 'focus'],
      rules2014: ItemEditionDetails(
        summary: 'Waterproof belt pouch compartmentalized to hold all non-costly spell material components.',
        description: 'A multi-pocketed leather pouch holding pinches of sulfur, feathers, bat fur, and other spell reagents.',
        properties: [
          'Provides all material components lacking a gp cost.',
          'Weight: 2 lbs.',
          'Cost: 25 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Waterproof belt pouch compartmentalized to hold all non-costly spell material components.',
        description: 'A multi-pocketed leather pouch holding pinches of sulfur, feathers, bat fur, and other spell reagents.',
        properties: [
          'Provides all material components lacking a gp cost.',
          'Weight: 2 lbs.',
          'Cost: 25 gp.',
        ],
      ),
    ),
    MagicItem(
      id: 'crowbar',
      name: 'Crowbar',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'tool', 'utility', 'leverage'],
      rules2014: ItemEditionDetails(
        summary: 'Grants Advantage on Strength checks where the crowbar\'s leverage can be applied.',
        description: 'A sturdy iron bar with a flattened, curved end designed for prying open stuck doors and chests.',
        properties: [
          'Advantage on applicable Strength ability checks.',
          'Weight: 5 lbs.',
          'Cost: 2 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Grants Advantage on Strength (Athletics) checks where leverage is applicable.',
        description: 'A sturdy iron bar with a flattened, curved end designed for prying open stuck doors and chests.',
        properties: [
          'Advantage on applicable Strength checks.',
          'Weight: 5 lbs.',
          'Cost: 2 gp.',
        ],
      ),
    ),
    MagicItem(
      id: 'druidic_focus',
      name: 'Druidic Focus (Sprig of Mistletoe / Totem / Wooden Staff / Yew Wand)',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'focus', 'druid', 'nature', 'spellcasting'],
      rules2014: ItemEditionDetails(
        summary: 'A special nature focus (sprig of mistletoe, totem, wooden staff, or yew wand) used to channel druid spells.',
        description: 'A consecrated symbol of natural order, replacing non-costly material components for druid and ranger spellcasting.',
        properties: [
          'Replaces non-costly material components for Druid spells.',
          'Weight: 1–4 lbs.',
          'Cost: 1–10 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'A special nature focus used to channel druid spells without non-costly components.',
        description: 'A consecrated symbol of natural order, replacing non-costly material components for druid and ranger spellcasting.',
        properties: [
          'Replaces non-costly material components for Druid spells.',
          'Weight: 1–4 lbs.',
          'Cost: 1–10 gp.',
        ],
      ),
    ),
    MagicItem(
      id: 'fishing_tackle',
      name: 'Fishing Tackle',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'survival', 'food', 'foraging'],
      rules2014: ItemEditionDetails(
        summary: 'Includes a wooden rod, silken line, cork bobbers, steel hooks, lead sinkers, and bait lures.',
        description: 'A complete kit for harvesting fish in wilderness rivers, lakes, and oceans during travel.',
        properties: [
          'Weight: 4 lbs.',
          'Cost: 1 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Includes a wooden rod, silken line, cork bobbers, steel hooks, lead sinkers, and bait lures.',
        description: 'A complete kit for harvesting fish in wilderness rivers, lakes, and oceans during travel.',
        properties: [
          'Weight: 4 lbs.',
          'Cost: 1 gp.',
        ],
      ),
    ),
    MagicItem(
      id: 'grappling_hook',
      name: 'Grappling Hook',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'climbing', 'utility'],
      rules2014: ItemEditionDetails(
        summary: 'Four-pronged iron hook tied to a rope to secure climbs over walls and ledges.',
        description: 'An anchor hook forged of resilient iron, essential for scale ascents and securing rope lines.',
        properties: [
          'Weight: 4 lbs.',
          'Cost: 2 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Four-pronged iron hook tied to a rope to secure climbs over walls and ledges.',
        description: 'An anchor hook forged of resilient iron, essential for scale ascents and securing rope lines.',
        properties: [
          'Weight: 4 lbs.',
          'Cost: 2 gp.',
        ],
      ),
    ),
    MagicItem(
      id: 'hammer',
      name: 'Hammer',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'tool', 'construction', 'bludgeoning'],
      damageAccent: DamageAccent.bludgeoning,
      rules2014: ItemEditionDetails(
        summary: 'One-handed utility hammer for driving iron spikes and carpentry work.',
        description: 'A flat-headed tool designed for driving pitons and iron spikes.',
        properties: [
          'Weight: 3 lbs.',
          'Cost: 1 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'One-handed utility hammer for driving iron spikes and carpentry work.',
        description: 'A flat-headed tool designed for driving pitons and iron spikes.',
        properties: [
          'Weight: 3 lbs.',
          'Cost: 1 gp.',
        ],
      ),
    ),
    MagicItem(
      id: 'hammer_sledge',
      name: 'Hammer, Sledge',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'tool', 'demolition', 'heavy', 'bludgeoning'],
      damageAccent: DamageAccent.bludgeoning,
      rules2014: ItemEditionDetails(
        summary: 'Heavy two-handed sledgehammer for demolition, breaking stone, and shattering locks.',
        description: 'A massive iron hammerhead mounted on a long wooden haft.',
        properties: [
          'Weight: 10 lbs.',
          'Cost: 2 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Heavy two-handed sledgehammer for demolition, breaking stone, and shattering locks.',
        description: 'A massive iron hammerhead mounted on a long wooden haft.',
        properties: [
          'Weight: 10 lbs.',
          'Cost: 2 gp.',
        ],
      ),
    ),
    MagicItem(
      id: 'healers_kit',
      name: 'Healer\'s Kit',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'healing', 'stabilize', 'medical', 'sustain'],
      rules2014: ItemEditionDetails(
        summary: 'Contains 10 uses. As an action, expend 1 use to stabilize a dying creature without making a Medicine check.',
        description: 'A leather pouch containing bandages, salves, and splints to treat battlefield casualties.',
        activation: '1 Action',
        properties: [
          '10 uses per kit.',
          'Stabilizes a creature at 0 HP with no roll required.',
          'Weight: 3 lbs.',
          'Cost: 5 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Contains 10 uses. As an action, expend 1 use to stabilize a dying creature without making a Medicine check.',
        description: 'A leather pouch containing bandages, salves, and splints to treat battlefield casualties.',
        activation: '1 Action',
        properties: [
          '10 uses per kit.',
          'Stabilizes a creature at 0 HP with no check.',
          'Weight: 3 lbs.',
          'Cost: 5 gp.',
        ],
      ),
    ),
    MagicItem(
      id: 'holy_water',
      name: 'Holy Water (Flask)',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'radiant', 'undead', 'fiend', 'combat'],
      damageAccent: DamageAccent.radiant,
      rules2014: ItemEditionDetails(
        summary: 'Improvised ranged attack (range 20 ft). On hit against a Fiend or Undead, deals 2d6 radiant damage.',
        description: 'Water blessed by a cleric or paladin through a ritual in a consecrated sanctuary.',
        activation: '1 Action',
        properties: [
          'Ranged Improvised Weapon Attack (20 ft).',
          'Deals 2d6 radiant damage against Fiends and Undead.',
          'Weight: 1 lb.',
          'Cost: 25 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Improvised ranged attack (range 20 ft). On hit against a Fiend or Undead, deals 2d6 radiant damage.',
        description: 'Water blessed by a cleric or paladin through a ritual in a consecrated sanctuary.',
        activation: '1 Action',
        properties: [
          'Ranged Improvised Weapon Attack (20 ft).',
          'Deals 2d6 radiant damage against Fiends and Undead.',
          'Weight: 1 lb.',
          'Cost: 25 gp.',
        ],
      ),
    ),
    MagicItem(
      id: 'hourglass',
      name: 'Hourglass',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'time', 'navigation', 'utility'],
      rules2014: ItemEditionDetails(
        summary: 'Standard sand timer measuring one exact hour of elapsed duration.',
        description: 'Two connected glass bulbs filled with fine measured sand in a protective brass or wooden frame.',
        properties: [
          'Weight: 1 lb.',
          'Cost: 25 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Standard sand timer measuring one exact hour of elapsed duration.',
        description: 'Two connected glass bulbs filled with fine measured sand in a protective brass or wooden frame.',
        properties: [
          'Weight: 1 lb.',
          'Cost: 25 gp.',
        ],
      ),
    ),
    MagicItem(
      id: 'hunting_trap',
      name: 'Hunting Trap',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'trap', 'restrain', 'control', 'piercing'],
      damageAccent: DamageAccent.piercing,
      rules2014: ItemEditionDetails(
        summary: 'Stepping on the trap requires a DC 13 Dex save or take 1d4 piercing damage and stop moving until escaping with a DC 13 Str check.',
        description: 'A heavy spring-loaded iron jaw anchored by a chain to a spike.',
        activation: '1 Action',
        properties: [
          'DC 13 Dexterity save or 1d4 piercing damage and immobilized.',
          'Escape requires DC 13 Strength check.',
          'Weight: 25 lbs.',
          'Cost: 5 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Stepping on the trap requires a DC 13 Dex save or take 1d4 piercing damage and stop moving until escaping with a DC 13 Str check.',
        description: 'A heavy spring-loaded iron jaw anchored by a chain to a spike.',
        activation: '1 Action',
        properties: [
          'DC 13 Dexterity save or 1d4 piercing damage and immobilized.',
          'Escape requires DC 13 Strength check.',
          'Weight: 25 lbs.',
          'Cost: 5 gp.',
        ],
      ),
    ),
    MagicItem(
      id: 'ink_bottle',
      name: 'Ink (1 Ounce Bottle)',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'writing', 'scrolls', 'spellbook'],
      rules2014: ItemEditionDetails(
        summary: '1 ounce bottle of black or dark sepia ink for scribing scrolls, maps, and spellbook pages.',
        description: 'High-grade gall or carbon ink stored in a stoppered glass vial.',
        properties: [
          'Weight: negligible.',
          'Cost: 10 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: '1 ounce bottle of black or dark sepia ink for scribing scrolls, maps, and spellbook pages.',
        description: 'High-grade gall or carbon ink stored in a stoppered glass vial.',
        properties: [
          'Weight: negligible.',
          'Cost: 10 gp.',
        ],
      ),
    ),
    MagicItem(
      id: 'ink_pen',
      name: 'Ink Pen',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'writing', 'scholarship'],
      rules2014: ItemEditionDetails(
        summary: 'Quill or dip pen with a carved wooden or metal nib for writing with ink.',
        description: 'A sturdy writing pen for cartography, legal contracts, and arcane study.',
        properties: [
          'Weight: negligible.',
          'Cost: 2 cp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Quill or dip pen with a carved wooden or metal nib for writing with ink.',
        description: 'A sturdy writing pen for cartography, legal contracts, and arcane study.',
        properties: [
          'Weight: negligible.',
          'Cost: 2 cp.',
        ],
      ),
    ),
    MagicItem(
      id: 'ladder_10ft',
      name: 'Ladder (10-Foot)',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'climbing', 'utility'],
      rules2014: ItemEditionDetails(
        summary: '10-foot wooden ladder with reinforced rungs.',
        description: 'A simple timber ladder for scaling roofs, dungeon drop-offs, and pit traps.',
        properties: [
          'Height: 10 feet.',
          'Weight: 25 lbs.',
          'Cost: 1 sp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: '10-foot wooden ladder with reinforced rungs.',
        description: 'A simple timber ladder for scaling roofs, dungeon drop-offs, and pit traps.',
        properties: [
          'Height: 10 feet.',
          'Weight: 25 lbs.',
          'Cost: 1 sp.',
        ],
      ),
    ),
    MagicItem(
      id: 'lamp',
      name: 'Lamp',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'light', 'oil', 'vision'],
      rules2014: ItemEditionDetails(
        summary: 'Casts bright light in a 15-foot radius and dim light for an additional 30 feet for 6 hours on 1 flask of oil.',
        description: 'A small clay or brass oil lamp with a wick spout.',
        properties: [
          'Bright light: 15-ft radius; Dim light: additional 30 ft.',
          'Burns for 6 hours on 1 flask of oil.',
          'Weight: 1 lb.',
          'Cost: 5 sp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Casts bright light in a 15-foot radius and dim light for an additional 30 feet for 6 hours on 1 flask of oil.',
        description: 'A small clay or brass oil lamp with a wick spout.',
        properties: [
          'Bright light: 15-ft radius; Dim light: additional 30 ft.',
          'Burns for 6 hours on 1 flask of oil.',
          'Weight: 1 lb.',
          'Cost: 5 sp.',
        ],
      ),
    ),
    MagicItem(
      id: 'bullseye_lantern',
      name: 'Lantern, Bullseye',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'light', 'vision', 'exploration'],
      rules2014: ItemEditionDetails(
        summary: 'Casts bright light in a 60-foot cone and dim light for an additional 60 feet for 6 hours on 1 flask of oil.',
        description: 'A hooded lantern with an adjustable shutter and reflective lens to focus light in a long directional beam.',
        properties: [
          'Bright light: 60-ft cone; Dim light: additional 60 ft.',
          'Burns for 6 hours per 1 pint (flask) of oil.',
          'Weight: 2 lbs.',
          'Cost: 10 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Casts bright light in a 60-foot cone and dim light for an additional 60 feet for 6 hours on 1 flask of oil.',
        description: 'A hooded lantern with an adjustable shutter and reflective lens to focus light in a long directional beam.',
        properties: [
          'Bright light: 60-ft cone; Dim light: additional 60 ft.',
          'Burns for 6 hours per flask of oil.',
          'Weight: 2 lbs.',
          'Cost: 10 gp.',
        ],
      ),
    ),
    MagicItem(
      id: 'hooded_lantern',
      name: 'Lantern, Hooded',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'light', 'vision', 'exploration'],
      rules2014: ItemEditionDetails(
        summary: 'Casts bright light in a 30-foot radius and dim light for an additional 30 feet for 6 hours on 1 flask of oil.',
        description: 'A cylindrical glass lantern with a movable metal hood that can be lowered to reduce light to 5-foot dim light.',
        properties: [
          'Bright light: 30-ft radius; Dim light: additional 30 ft.',
          'Hood down: 5-ft dim light.',
          'Weight: 2 lbs.',
          'Cost: 5 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Casts bright light in a 30-foot radius and dim light for an additional 30 feet for 6 hours on 1 flask of oil.',
        description: 'A cylindrical glass lantern with a movable metal hood that can be lowered to reduce light to 5-foot dim light.',
        properties: [
          'Bright light: 30-ft radius; Dim light: additional 30 ft.',
          'Hood down: 5-ft dim light.',
          'Weight: 2 lbs.',
          'Cost: 5 gp.',
        ],
      ),
    ),
    MagicItem(
      id: 'lock',
      name: 'Lock',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'security', 'locks', 'doors'],
      rules2014: ItemEditionDetails(
        summary: 'Comes with a key. Opening without key requires a DC 15 Thieves\' Tools check.',
        description: 'An iron padlock with a brass tumbler mechanism.',
        properties: [
          'DC 15 Thieves\' Tools check to pick.',
          'Weight: 1 lb.',
          'Cost: 10 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Comes with a key. Opening without key requires a DC 15 Dexterity (Sleight of Hand) check using Thieves\' Tools.',
        description: 'An iron padlock with a brass tumbler mechanism.',
        properties: [
          'DC 15 Thieves\' Tools check to pick.',
          'Weight: 1 lb.',
          'Cost: 10 gp.',
        ],
      ),
    ),
    MagicItem(
      id: 'magnifying_glass',
      name: 'Magnifying Glass',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'investigation', 'optical', 'fire'],
      damageAccent: DamageAccent.fire,
      rules2014: ItemEditionDetails(
        summary: 'Grants Advantage on ability checks made to appraise or inspect small or detailed items. Can light tinder in direct sunlight.',
        description: 'A convex glass lens mounted in a polished brass rim with a handle.',
        properties: [
          'Advantage on detailed appraisal and examination checks.',
          'Lights tinder in 5 minutes under direct sunlight.',
          'Weight: negligible.',
          'Cost: 100 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Grants Advantage on ability checks made to inspect small or detailed objects. Can start a fire under bright sunlight.',
        description: 'A convex glass lens mounted in a polished brass rim with a handle.',
        properties: [
          'Advantage on detailed investigation and appraisal checks.',
          'Weight: negligible.',
          'Cost: 100 gp.',
        ],
      ),
    ),
    MagicItem(
      id: 'manacles',
      name: 'Manacles',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'restraint', 'security', 'control'],
      rules2014: ItemEditionDetails(
        summary: 'Binds a Small or Medium creature. Escaping requires DC 20 Dex check; breaking requires DC 20 Str check; picking requires DC 15 Thieves\' Tools.',
        description: 'A pair of hinged iron wrist shackles connected by welded chain links.',
        properties: [
          'Escape DC: 20 Dexterity; Break DC: 20 Strength; Pick DC: 15 Thieves\' Tools.',
          'Weight: 6 lbs.',
          'Cost: 2 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Binds a Small or Medium creature. Escaping requires DC 20 Dex check; breaking requires DC 20 Str check; picking requires DC 15 Thieves\' Tools.',
        description: 'A pair of hinged iron wrist shackles connected by welded chain links.',
        properties: [
          'Escape DC: 20 Dexterity; Break DC: 20 Strength; Pick DC: 15 Thieves\' Tools.',
          'Weight: 6 lbs.',
          'Cost: 2 gp.',
        ],
      ),
    ),
    MagicItem(
      id: 'mess_kit',
      name: 'Mess Kit',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'camp', 'dining', 'survival'],
      rules2014: ItemEditionDetails(
        summary: 'Contains a cup and simple cutlery. The box clamps together to store the pieces and can serve as a cooking pan.',
        description: 'A nesting metal container holding a plate, bowl, cup, fork, and spoon.',
        properties: [
          'Weight: 1 lb.',
          'Cost: 2 sp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Contains a cup and simple cutlery. The box clamps together to store the pieces and can serve as a cooking pan.',
        description: 'A nesting metal container holding a plate, bowl, cup, fork, and spoon.',
        properties: [
          'Weight: 1 lb.',
          'Cost: 2 sp.',
        ],
      ),
    ),
    MagicItem(
      id: 'mirror_steel',
      name: 'Mirror, Steel',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'scouting', 'signaling', 'optical'],
      rules2014: ItemEditionDetails(
        summary: 'Polished steel reflective hand mirror used for looking around corners or signaling over long distances.',
        description: 'A polished metal plate that does not shatter like glass when struck.',
        properties: [
          'Weight: ½ lb.',
          'Cost: 5 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Polished steel reflective hand mirror used for looking around corners or signaling over long distances.',
        description: 'A polished metal plate that does not shatter like glass when struck.',
        properties: [
          'Weight: ½ lb.',
          'Cost: 5 gp.',
        ],
      ),
    ),
    MagicItem(
      id: 'oil_flask',
      name: 'Oil (Flask)',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'fire', 'fuel', 'combat', 'utility'],
      damageAccent: DamageAccent.fire,
      rules2014: ItemEditionDetails(
        summary: 'Used as fuel for lanterns (6 hrs) or splashed as a ranged attack (20 ft) to add 5 fire damage when ignited.',
        description: 'A clay flask containing 1 pint of combustible mineral oil.',
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
        summary: 'Used as fuel for lanterns (6 hrs) or splashed as a ranged attack (20 ft) to add 5 fire damage when ignited.',
        description: 'A clay flask containing 1 pint of combustible mineral oil.',
        activation: '1 Action',
        properties: [
          'Fuel: 6 hours in a lantern.',
          'Attack: Ranged improvised weapon (20 ft).',
          'Ignition: Deals 5 extra fire damage on fire attacks.',
          'Weight: 1 lb.',
          'Cost: 1 sp.',
        ],
      ),
    ),
    MagicItem(
      id: 'paper_sheet',
      name: 'Paper (One Sheet)',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'writing', 'maps', 'letters'],
      rules2014: ItemEditionDetails(
        summary: 'A single leaf of rag or wood pulp paper suitable for maps, letters, and rubbings.',
        description: 'Smooth pressed paper for scribing and drawing.',
        properties: [
          'Weight: negligible.',
          'Cost: 2 sp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'A single leaf of rag or wood pulp paper suitable for maps, letters, and rubbings.',
        description: 'Smooth pressed paper for scribing and drawing.',
        properties: [
          'Weight: negligible.',
          'Cost: 2 sp.',
        ],
      ),
    ),
    MagicItem(
      id: 'parchment_sheet',
      name: 'Parchment (One Sheet)',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'writing', 'scrolls', 'documents'],
      rules2014: ItemEditionDetails(
        summary: 'Treated animal skin parchment, durable and weather-resistant for magical scrolls and official edicts.',
        description: 'A durable sheet of scraped and treated calf or sheep vellum.',
        properties: [
          'Weight: negligible.',
          'Cost: 1 sp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Treated animal skin parchment, durable and weather-resistant for magical scrolls and official edicts.',
        description: 'A durable sheet of scraped and treated calf or sheep vellum.',
        properties: [
          'Weight: negligible.',
          'Cost: 1 sp.',
        ],
      ),
    ),
    MagicItem(
      id: 'perfume_vial',
      name: 'Perfume (Vial)',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'social', 'aristocracy'],
      rules2014: ItemEditionDetails(
        summary: 'Aromatic essential oils providing sweet fragrance to mask dungeon stench or impress nobility.',
        description: 'A decorative cut-crystal vial of distilled floral essence.',
        properties: [
          'Weight: negligible.',
          'Cost: 5 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Aromatic essential oils providing sweet fragrance to mask dungeon stench or impress nobility.',
        description: 'A decorative cut-crystal vial of distilled floral essence.',
        properties: [
          'Weight: negligible.',
          'Cost: 5 gp.',
        ],
      ),
    ),
    MagicItem(
      id: 'pick_miners',
      name: 'Pick, Miner\'s',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'mining', 'tool', 'excavation', 'piercing'],
      damageAccent: DamageAccent.piercing,
      rules2014: ItemEditionDetails(
        summary: 'Two-handed pick for breaking through subterranean rock, masonry, and mineral veins.',
        description: 'A heavy pointed iron pick head fitted to an ash haft.',
        properties: [
          'Weight: 10 lbs.',
          'Cost: 2 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Two-handed pick for breaking through subterranean rock, masonry, and mineral veins.',
        description: 'A heavy pointed iron pick head fitted to an ash haft.',
        properties: [
          'Weight: 10 lbs.',
          'Cost: 2 gp.',
        ],
      ),
    ),
    MagicItem(
      id: 'piton',
      name: 'Piton',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'climbing', 'anchors', 'iron'],
      rules2014: ItemEditionDetails(
        summary: 'Iron spike with an eyelet for passing rope through during climbing or spiking doors shut.',
        description: 'A forged steel spike driven into rock crevices to create rope anchor points.',
        properties: [
          'Weight: ¼ lb.',
          'Cost: 5 cp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Iron spike with an eyelet for passing rope through during climbing or spiking doors shut.',
        description: 'A forged steel spike driven into rock crevices to create rope anchor points.',
        properties: [
          'Weight: ¼ lb.',
          'Cost: 5 cp.',
        ],
      ),
    ),
    MagicItem(
      id: 'poison_basic',
      name: 'Poison, Basic (Vial)',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'poison', 'combat', 'coating'],
      damageAccent: DamageAccent.poison,
      rules2014: ItemEditionDetails(
        summary: 'Applied to one slashing/piercing weapon or up to 3 pieces of ammunition. Hit creature must succeed on DC 10 Constitution save or take 1d4 poison damage.',
        description: 'A toxic extract of nightshade, hemlock, or serpent venom.',
        activation: '1 Action',
        properties: [
          'Coats 1 weapon or 3 ammunition pieces for 1 minute.',
          'DC 10 Constitution save or 1d4 poison damage on hit.',
          'Weight: negligible.',
          'Cost: 100 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Applied to one slashing/piercing weapon or up to 3 pieces of ammunition. Hit creature must succeed on DC 10 Constitution save or take 1d4 poison damage.',
        description: 'A toxic extract of nightshade, hemlock, or serpent venom.',
        activation: '1 Action',
        properties: [
          'Coats 1 weapon or 3 ammunition pieces for 1 minute.',
          'DC 10 Constitution save or 1d4 poison damage.',
          'Weight: negligible.',
          'Cost: 100 gp.',
        ],
      ),
    ),
    MagicItem(
      id: 'pole_10ft',
      name: 'Pole (10-Foot)',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'traps', 'utility', 'dungeon'],
      rules2014: ItemEditionDetails(
        summary: 'A 10-foot wooden pole used for probing suspicious floor tiles, testing water depth, and triggering pressure plates.',
        description: 'The legendary dungeon-delver\'s ten-foot wooden pole.',
        properties: [
          'Length: 10 feet.',
          'Weight: 7 lbs.',
          'Cost: 5 cp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'A 10-foot wooden pole used for probing suspicious floor tiles, testing water depth, and triggering pressure plates.',
        description: 'The legendary dungeon-delver\'s ten-foot wooden pole.',
        properties: [
          'Length: 10 feet.',
          'Weight: 7 lbs.',
          'Cost: 5 cp.',
        ],
      ),
    ),
    MagicItem(
      id: 'ram_portable',
      name: 'Ram, Portable',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'breaching', 'doors', 'demolition'],
      rules2014: ItemEditionDetails(
        summary: 'Grants +4 bonus on Strength checks to break down doors. Another character can assist to grant Advantage.',
        description: 'An iron-shod timber beam fitted with handles for one or two persons.',
        properties: [
          '+4 bonus to Strength checks made to breach doors.',
          'Assisting helper grants Advantage.',
          'Weight: 35 lbs.',
          'Cost: 4 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Grants +4 bonus on Strength checks to break down doors. Another character can assist to grant Advantage.',
        description: 'An iron-shod timber beam fitted with handles for one or two persons.',
        properties: [
          '+4 bonus to Strength checks made to breach doors.',
          'Weight: 35 lbs.',
          'Cost: 4 gp.',
        ],
      ),
    ),
    MagicItem(
      id: 'rations',
      name: 'Rations (1 Day)',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'food', 'survival'],
      rules2014: ItemEditionDetails(
        summary: 'Compact dry food suitable for extended travel, including jerky, dried fruit, hardtack, and nuts.',
        description: 'One day\'s worth of preserved survival sustenance for a Medium creature.',
        properties: [
          'Weight: 2 lbs.',
          'Cost: 5 sp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Compact dry food suitable for extended travel, including jerky, dried fruit, hardtack, and nuts.',
        description: 'One day\'s worth of preserved survival sustenance for a Medium creature.',
        properties: [
          'Weight: 2 lbs.',
          'Cost: 5 sp.',
        ],
      ),
    ),
    MagicItem(
      id: 'rope_hempen',
      name: 'Rope, Hempen (50 Feet)',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'rope', 'climbing', 'utility'],
      rules2014: ItemEditionDetails(
        summary: '50-foot natural hemp rope. Has 2 hit points and can be burst with a DC 17 Strength check.',
        description: 'Standard braided natural hemp cordage for all climbing, hauling, and binding needs.',
        properties: [
          'Length: 50 feet.',
          'HP: 2; Burst DC: 17 Strength.',
          'Weight: 10 lbs.',
          'Cost: 1 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: '50-foot natural hemp rope. Has 2 hit points and can be burst with a DC 17 Strength check.',
        description: 'Standard braided natural hemp cordage for all climbing, hauling, and binding needs.',
        properties: [
          'Length: 50 feet.',
          'HP: 2; Burst DC: 17 Strength.',
          'Weight: 10 lbs.',
          'Cost: 1 gp.',
        ],
      ),
    ),
    MagicItem(
      id: 'rope_silk',
      name: 'Rope, Silk (50 Feet)',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'utility', 'climbing', 'restraint'],
      rules2014: ItemEditionDetails(
        summary: '50-foot lightweight braided silk rope. Has 2 hit points and can be burst with a DC 17 Strength check.',
        description: 'Strong, supple rope woven from spider or silkworm thread, much lighter than hempen rope.',
        properties: [
          'Length: 50 feet.',
          'HP: 2; Burst DC: 17 Strength.',
          'Weight: 5 lbs.',
          'Cost: 10 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: '50-foot lightweight braided silk rope. Has 2 hit points and can be burst with a DC 17 Strength check.',
        description: 'Strong, supple rope woven from spider or silkworm thread, much lighter than hempen rope.',
        properties: [
          'Length: 50 feet.',
          'HP: 2; Burst DC: 17 Strength.',
          'Weight: 5 lbs.',
          'Cost: 10 gp.',
        ],
      ),
    ),
    MagicItem(
      id: 'scale_merchants',
      name: 'Scale, Merchant\'s',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'trade', 'measurement', 'coins'],
      rules2014: ItemEditionDetails(
        summary: 'Balanced brass balance scale with precise counterweights for measuring precious metals and gems.',
        description: 'A calibrated balance scale essential for trade and banking.',
        properties: [
          'Weight: 3 lbs.',
          'Cost: 5 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Balanced brass balance scale with precise counterweights for measuring precious metals and gems.',
        description: 'A calibrated balance scale essential for trade and banking.',
        properties: [
          'Weight: 3 lbs.',
          'Cost: 5 gp.',
        ],
      ),
    ),
    MagicItem(
      id: 'sealing_wax',
      name: 'Sealing Wax',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'writing', 'security', 'letters'],
      rules2014: ItemEditionDetails(
        summary: 'Stick of red or black resin wax for sealing letters and identifying tampered documents.',
        description: 'High-adhesion wax melted by flame and impressed with a signet ring.',
        properties: [
          'Weight: negligible.',
          'Cost: 5 sp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Stick of red or black resin wax for sealing letters and identifying tampered documents.',
        description: 'High-adhesion wax melted by flame and impressed with a signet ring.',
        properties: [
          'Weight: negligible.',
          'Cost: 5 sp.',
        ],
      ),
    ),
    MagicItem(
      id: 'shovel',
      name: 'Shovel',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'excavation', 'tool'],
      rules2014: ItemEditionDetails(
        summary: 'Sturdy steel-bladed spade with a wooden handle for digging trenches and unearthing burial vaults.',
        description: 'A standard excavation tool.',
        properties: [
          'Weight: 5 lbs.',
          'Cost: 2 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Sturdy steel-bladed spade with a wooden handle for digging trenches and unearthing burial vaults.',
        description: 'A standard excavation tool.',
        properties: [
          'Weight: 5 lbs.',
          'Cost: 2 gp.',
        ],
      ),
    ),
    MagicItem(
      id: 'signal_whistle',
      name: 'Signal Whistle',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'signaling', 'sound', 'scouting'],
      rules2014: ItemEditionDetails(
        summary: 'Produces a piercing high-pitched blast audible up to a quarter mile away.',
        description: 'A small brass whistle on a neck lanyard.',
        properties: [
          'Weight: negligible.',
          'Cost: 5 cp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Produces a piercing high-pitched blast audible up to a quarter mile away.',
        description: 'A small brass whistle on a neck lanyard.',
        properties: [
          'Weight: negligible.',
          'Cost: 5 cp.',
        ],
      ),
    ),
    MagicItem(
      id: 'signet_ring',
      name: 'Signet Ring',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'nobility', 'identification', 'letters'],
      rules2014: ItemEditionDetails(
        summary: 'Engraved with the heraldic crest of a noble house, guild, or sovereign order.',
        description: 'A gold or silver ring with an intaglio crest for stamping heated sealing wax.',
        properties: [
          'Weight: negligible.',
          'Cost: 5 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Engraved with the heraldic crest of a noble house, guild, or sovereign order.',
        description: 'A gold or silver ring with an intaglio crest for stamping heated sealing wax.',
        properties: [
          'Weight: negligible.',
          'Cost: 5 gp.',
        ],
      ),
    ),
    MagicItem(
      id: 'spellbook',
      name: 'Spellbook',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'wizard', 'arcane', 'spells', 'grimoire'],
      rules2014: ItemEditionDetails(
        summary: 'Essential for wizards. A leather-bound tome holding 100 blank vellum pages for scribing spells.',
        description: 'A wizard\'s grimoire bound with protective metal corner-caps and a locking clasp.',
        properties: [
          'Holds 100 pages for spell transcription.',
          'Weight: 3 lbs.',
          'Cost: 50 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Essential for wizards. A leather-bound tome holding 100 blank vellum pages for scribing spells.',
        description: 'A wizard\'s grimoire bound with protective metal corner-caps and a locking clasp.',
        properties: [
          'Holds 100 pages for spell transcription.',
          'Weight: 3 lbs.',
          'Cost: 50 gp.',
        ],
      ),
    ),
    MagicItem(
      id: 'spikes_iron',
      name: 'Spikes, Iron (10)',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'iron', 'dungeon', 'doors'],
      rules2014: ItemEditionDetails(
        summary: 'Ten heavy iron spikes for wedging dungeon doors open or closed and securing leverage points.',
        description: 'Solid forged wedge spikes driven with a hammer.',
        properties: [
          'Weight: 5 lbs.',
          'Cost: 1 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Ten heavy iron spikes for wedging dungeon doors open or closed and securing leverage points.',
        description: 'Solid forged wedge spikes driven with a hammer.',
        properties: [
          'Weight: 5 lbs.',
          'Cost: 1 gp.',
        ],
      ),
    ),
    MagicItem(
      id: 'spyglass',
      name: 'Spyglass',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'vision', 'scouting', 'optical'],
      rules2014: ItemEditionDetails(
        summary: 'Objects viewed through the spyglass are magnified to twice their size.',
        description: 'A telescoping brass tube with polished glass lenses for naval navigation and long-range scouting.',
        properties: [
          '2x visual magnification.',
          'Weight: 1 lb.',
          'Cost: 1,000 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Objects viewed through the spyglass are magnified to twice their size.',
        description: 'A telescoping brass tube with polished glass lenses for naval navigation and long-range scouting.',
        properties: [
          '2x visual magnification.',
          'Weight: 1 lb.',
          'Cost: 1,000 gp.',
        ],
      ),
    ),
    MagicItem(
      id: 'tent_two_person',
      name: 'Tent, Two-Person',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'shelter', 'camp', 'survival'],
      rules2014: ItemEditionDetails(
        summary: 'A canvas shelter with collapsible wooden poles and stakes, sleeping up to two Medium creatures.',
        description: 'A weather-treated canvas tent providing shelter during long rests.',
        properties: [
          'Capacity: 2 Medium creatures.',
          'Weight: 20 lbs.',
          'Cost: 2 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'A canvas shelter with collapsible wooden poles and stakes, sleeping up to two Medium creatures.',
        description: 'A weather-treated canvas tent providing shelter during long rests.',
        properties: [
          'Capacity: 2 Medium creatures.',
          'Weight: 20 lbs.',
          'Cost: 2 gp.',
        ],
      ),
    ),
    MagicItem(
      id: 'tinderbox',
      name: 'Tinderbox',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'fire', 'camp', 'utility'],
      damageAccent: DamageAccent.fire,
      rules2014: ItemEditionDetails(
        summary: 'Contains flint, fire steel, and dry tinder. Lighting a torch takes 1 action; lighting a campfire takes 1 minute.',
        description: 'A small metal box protecting dry shredded bark, charred linen, flint, and steel striker.',
        activation: '1 Action (torch) / 1 Minute (fire)',
        properties: [
          'Starts fires and torches.',
          'Weight: 1 lb.',
          'Cost: 5 sp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Contains flint, fire steel, and dry tinder. Lighting a torch takes 1 action; lighting a campfire takes 1 minute.',
        description: 'A small metal box protecting dry shredded bark, charred linen, flint, and steel striker.',
        activation: '1 Action / 1 Minute',
        properties: [
          'Starts fires and torches.',
          'Weight: 1 lb.',
          'Cost: 5 sp.',
        ],
      ),
    ),
    MagicItem(
      id: 'torch',
      name: 'Torch',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'light', 'fire', 'exploration'],
      damageAccent: DamageAccent.fire,
      rules2014: ItemEditionDetails(
        summary: 'Burns for 1 hour, shedding bright light in a 20-foot radius and dim light for an additional 20 feet. Deals 1 fire damage on hit.',
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
        summary: 'Burns for 1 hour, shedding bright light in a 20-foot radius and dim light for an additional 20 feet. Deals 1 fire damage on hit.',
        description: 'A wooden rod wrapped in pitch-soaked cloth.',
        properties: [
          'Bright light: 20-ft radius; Dim light: additional 20 ft.',
          'Burns for 1 hour.',
          'Melee attack deals 1 fire damage.',
          'Weight: 1 lb.',
          'Cost: 1 cp.',
        ],
      ),
    ),
    MagicItem(
      id: 'whetstone',
      name: 'Whetstone',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'maintenance', 'weapons'],
      rules2014: ItemEditionDetails(
        summary: 'Fine abrasive stone used to hone bladed weapons and remove burrs.',
        description: 'A dual-grit polishing stone for weapon edge maintenance.',
        properties: [
          'Weight: 1 lb.',
          'Cost: 1 cp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Fine abrasive stone used to hone bladed weapons and remove burrs.',
        description: 'A dual-grit polishing stone for weapon edge maintenance.',
        properties: [
          'Weight: 1 lb.',
          'Cost: 1 cp.',
        ],
      ),
    ),

    // =========================================================================
    // 3. CLOTHES & APPAREL
    // =========================================================================
    MagicItem(
      id: 'clothes_common',
      name: 'Clothes, Common',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'clothing', 'apparel'],
      rules2014: ItemEditionDetails(
        summary: 'Simple peasant or working-class garments consisting of a tunic, breeches, and cloth wrap.',
        description: 'Homespun wool or linen clothing suitable for everyday farm or labor work.',
        properties: [
          'Weight: 3 lbs.',
          'Cost: 5 sp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Simple peasant or working-class garments consisting of a tunic, breeches, and cloth wrap.',
        description: 'Homespun wool or linen clothing suitable for everyday farm or labor work.',
        properties: [
          'Weight: 3 lbs.',
          'Cost: 5 sp.',
        ],
      ),
    ),
    MagicItem(
      id: 'clothes_costume',
      name: 'Clothes, Costume',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'clothing', 'disguise', 'performance'],
      rules2014: ItemEditionDetails(
        summary: 'Theatrical clothing with vibrant colors, props, and exaggerated silhouettes for acting or disguise.',
        description: 'Costume attire designed for stage actors, jesters, and disguise infiltration.',
        properties: [
          'Weight: 4 lbs.',
          'Cost: 5 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Theatrical clothing with vibrant colors, props, and exaggerated silhouettes for acting or disguise.',
        description: 'Costume attire designed for stage actors, jesters, and disguise infiltration.',
        properties: [
          'Weight: 4 lbs.',
          'Cost: 5 gp.',
        ],
      ),
    ),
    MagicItem(
      id: 'clothes_fine',
      name: 'Clothes, Fine',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'clothing', 'aristocracy', 'social'],
      rules2014: ItemEditionDetails(
        summary: 'High-fashion velvet, brocade, and silk apparel worn by aristocrats, diplomats, and wealthy merchants.',
        description: 'Tailored courtier garments adorned with embroidery and subtle filigree.',
        properties: [
          'Weight: 6 lbs.',
          'Cost: 15 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'High-fashion velvet, brocade, and silk apparel worn by aristocrats, diplomats, and wealthy merchants.',
        description: 'Tailored courtier garments adorned with embroidery and subtle filigree.',
        properties: [
          'Weight: 6 lbs.',
          'Cost: 15 gp.',
        ],
      ),
    ),
    MagicItem(
      id: 'clothes_travelers',
      name: 'Clothes, Traveler\'s',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'clothing', 'travel', 'exploration'],
      rules2014: ItemEditionDetails(
        summary: 'Sturdy leather-reinforced boots, wool cloak, tunic, and trousers designed for long journeys in varied weather.',
        description: 'Comfortable, durable expedition wear resilient to trail mud and rain.',
        properties: [
          'Weight: 4 lbs.',
          'Cost: 2 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Sturdy leather-reinforced boots, wool cloak, tunic, and trousers designed for long journeys in varied weather.',
        description: 'Comfortable, durable expedition wear resilient to trail mud and rain.',
        properties: [
          'Weight: 4 lbs.',
          'Cost: 2 gp.',
        ],
      ),
    ),
    MagicItem(
      id: 'robes',
      name: 'Robes',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['gear', 'clothing', 'arcane', 'divine'],
      rules2014: ItemEditionDetails(
        summary: 'Flowing ceremonial or scholarly vestments favored by wizards, monks, and clergy.',
        description: 'Floor-length cloth robes with deep cowl and wide sleeves.',
        properties: [
          'Weight: 4 lbs.',
          'Cost: 1 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Flowing ceremonial or scholarly vestments favored by wizards, monks, and clergy.',
        description: 'Floor-length cloth robes with deep cowl and wide sleeves.',
        properties: [
          'Weight: 4 lbs.',
          'Cost: 1 gp.',
        ],
      ),
    ),

    // =========================================================================
    // 4. SPELLCASTING FOCI
    // =========================================================================
    MagicItem(
      id: 'arcane_focus_wand',
      name: 'Arcane Focus (Wand / Crystal / Orb)',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['focus', 'spellcasting', 'arcane', 'wizard', 'sorcerer', 'warlock'],
      rules2014: ItemEditionDetails(
        summary: 'A special item designed to channel the power of arcane spells, substituting for non-costly material components.',
        description: 'Crafted from crystal, orbs of glass, carved wands of weirwood, or polished rods.',
        properties: [
          'Substitutes for material components with no gp cost.',
          'Weight: 1–3 lbs.',
          'Cost: 5–20 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'A spellcasting focus designed to channel arcane spells, replacing non-costly material components.',
        description: 'Crafted from crystal, orbs of glass, carved wands of weirwood, or polished rods.',
        properties: [
          'Substitutes for material components with no gp cost.',
          'Weight: 1–3 lbs.',
          'Cost: 5–20 gp.',
        ],
      ),
    ),
    MagicItem(
      id: 'holy_symbol_amulet',
      name: 'Holy Symbol (Amulet / Emblem / Reliquary)',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['focus', 'spellcasting', 'divine', 'cleric', 'paladin'],
      damageAccent: DamageAccent.radiant,
      rules2014: ItemEditionDetails(
        summary: 'A representation of a deity or pantheon used as a divine spellcasting focus. Can be worn as an amulet or emblazoned on a shield.',
        description: 'Consecrated icon, sunburst, or miniature reliquary honoring a divine power.',
        properties: [
          'Can be emblazoned on a shield or worn openly.',
          'Substitutes for non-costly divine material components.',
          'Weight: 1 lb.',
          'Cost: 5 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'A representation of a deity or pantheon used as a divine spellcasting focus. Can be worn as an amulet or emblazoned on a shield.',
        description: 'Consecrated icon, sunburst, or miniature reliquary honoring a divine power.',
        properties: [
          'Can be emblazoned on a shield or worn openly.',
          'Substitutes for non-costly divine material components.',
          'Weight: 1 lb.',
          'Cost: 5 gp.',
        ],
      ),
    ),

    // =========================================================================
    // 5. TOOLS & KITS
    // =========================================================================
    MagicItem(
      id: 'thieves_tools',
      name: 'Thieves\' Tools',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['tools', 'lockpicking', 'traps', 'dexterity'],
      rules2014: ItemEditionDetails(
        summary: 'Allows adding proficiency bonus to ability checks made to disarm traps or pick mechanical locks.',
        description: 'A set of lock picks, tension wrenches, small mirror, narrow file, and pliers in a folding leather case.',
        properties: [
          'Used for picking locks and disarming mechanical traps.',
          'Weight: 1 lb.',
          'Cost: 25 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Allows adding proficiency bonus to Dexterity checks made with thieves\' tools to pick locks or disarm traps. Uses DC rules specified in the 2024 equipment chapter.',
        description: 'A set of lock picks, tension wrenches, small mirror, narrow file, and pliers in a folding leather case.',
        properties: [
          'Used for Pick Lock (Sleight of Hand) and Disarm Trap checks.',
          'Weight: 1 lb.',
          'Cost: 25 gp.',
        ],
      ),
    ),
    MagicItem(
      id: 'alchemists_supplies',
      name: 'Alchemist\'s Supplies',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['tools', 'crafting', 'alchemy', 'potions'],
      rules2014: ItemEditionDetails(
        summary: 'Includes glass beakers, stirring rods, mortar and pestle, and common chemical reagents for brewing and identification.',
        description: 'A portable laboratory kit for synthesizing acids, alchemist\'s fire, and analyzing strange residues.',
        properties: [
          'Proficiency allows crafting alchemical items and identifying substances.',
          'Weight: 8 lbs.',
          'Cost: 50 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Includes glass beakers, stirring rods, mortar and pestle, and common chemical reagents for brewing and identification.',
        description: 'A portable laboratory kit for synthesizing acids, alchemist\'s fire, and analyzing strange residues.',
        properties: [
          'Proficiency allows crafting alchemical items and identifying substances.',
          'Weight: 8 lbs.',
          'Cost: 50 gp.',
        ],
      ),
    ),
    MagicItem(
      id: 'brewers_supplies',
      name: 'Brewer\'s Supplies',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['tools', 'crafting', 'brewing', 'food'],
      rules2014: ItemEditionDetails(
        summary: 'Includes a siphon, hydrometer, hops, yeast, and kegging tubes for fermenting beer, cider, and spirits.',
        description: 'Equipment needed to brew quality ales, stouts, and purifying water supplies.',
        properties: [
          'Weight: 9 lbs.',
          'Cost: 20 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Includes a siphon, hydrometer, hops, yeast, and kegging tubes for fermenting beer, cider, and spirits.',
        description: 'Equipment needed to brew quality ales, stouts, and purifying water supplies.',
        properties: [
          'Weight: 9 lbs.',
          'Cost: 20 gp.',
        ],
      ),
    ),
    MagicItem(
      id: 'calligraphers_supplies',
      name: 'Calligrapher\'s Supplies',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['tools', 'writing', 'scrolls', 'artisan'],
      rules2014: ItemEditionDetails(
        summary: 'Specialized inks, gold leaf, varied nibs, and ruling stones for illuminating manuscripts and writing official scrolls.',
        description: 'Precision writing implements for creating beautiful calligraphy and copying scrolls.',
        properties: [
          'Weight: 5 lbs.',
          'Cost: 10 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Specialized inks, gold leaf, varied nibs, and ruling stones for illuminating manuscripts and writing official scrolls.',
        description: 'Precision writing implements for creating beautiful calligraphy and copying scrolls.',
        properties: [
          'Weight: 5 lbs.',
          'Cost: 10 gp.',
        ],
      ),
    ),
    MagicItem(
      id: 'carpenters_tools',
      name: 'Carpenter\'s Tools',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['tools', 'crafting', 'woodworking', 'construction'],
      rules2014: ItemEditionDetails(
        summary: 'Includes a saw, hammer, nails, adze, square, plane, and chisel for woodworking and building structures.',
        description: 'Essential kit for building barricades, bridges, doors, and timber repairs.',
        properties: [
          'Weight: 6 lbs.',
          'Cost: 8 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Includes a saw, hammer, nails, adze, square, plane, and chisel for woodworking and building structures.',
        description: 'Essential kit for building barricades, bridges, doors, and timber repairs.',
        properties: [
          'Weight: 6 lbs.',
          'Cost: 8 gp.',
        ],
      ),
    ),
    MagicItem(
      id: 'cartographers_tools',
      name: 'Cartographer\'s Tools',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['tools', 'navigation', 'maps', 'exploration'],
      rules2014: ItemEditionDetails(
        summary: 'Compasses, fine calipers, inks, measuring cords, and parchment for drafting accurate dungeon and overland maps.',
        description: 'Precision mapping instruments for surveying unexplored territory.',
        properties: [
          'Weight: 6 lbs.',
          'Cost: 15 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Compasses, fine calipers, inks, measuring cords, and parchment for drafting accurate dungeon and overland maps.',
        description: 'Precision mapping instruments for surveying unexplored territory.',
        properties: [
          'Weight: 6 lbs.',
          'Cost: 15 gp.',
        ],
      ),
    ),
    MagicItem(
      id: 'cobblers_tools',
      name: 'Cobbler\'s Tools',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['tools', 'crafting', 'leather', 'boots'],
      rules2014: ItemEditionDetails(
        summary: 'Includes a cobbler\'s last, awl, leather knives, thread, and replacement heel soles.',
        description: 'Tools for repairing traveler\'s boots and crafting hidden boot-heel compartments.',
        properties: [
          'Weight: 5 lbs.',
          'Cost: 5 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Includes a cobbler\'s last, awl, leather knives, thread, and replacement heel soles.',
        description: 'Tools for repairing traveler\'s boots and crafting hidden boot-heel compartments.',
        properties: [
          'Weight: 5 lbs.',
          'Cost: 5 gp.',
        ],
      ),
    ),
    MagicItem(
      id: 'cooks_utensils',
      name: 'Cook\'s Utensils',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['tools', 'cooking', 'survival', 'camp', 'sustain'],
      rules2014: ItemEditionDetails(
        summary: 'Includes an iron pot, skillet, knives, seasoning vials, and stirring spoons for preparing nourishing meals.',
        description: 'Field cooking gear that turns foraged game into wholesome banquet meals during long rests.',
        properties: [
          'Weight: 8 lbs.',
          'Cost: 1 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Includes an iron pot, skillet, knives, seasoning vials, and stirring spoons for preparing nourishing meals.',
        description: 'Field cooking gear that turns foraged game into wholesome banquet meals during long rests.',
        properties: [
          'Weight: 8 lbs.',
          'Cost: 1 gp.',
        ],
      ),
    ),
    MagicItem(
      id: 'disguise_kit',
      name: 'Disguise Kit',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['tools', 'deception', 'disguise', 'stealth'],
      rules2014: ItemEditionDetails(
        summary: 'Includes makeup, false hair, props, prosthetics, and costume jewelry for altering one\'s physical appearance.',
        description: 'Professional disguise cosmetics to impersonate guards, nobles, or commoners.',
        properties: [
          'Adds proficiency to checks made to create a visual disguise.',
          'Weight: 3 lbs.',
          'Cost: 25 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Includes makeup, false hair, props, prosthetics, and costume jewelry for altering one\'s physical appearance.',
        description: 'Professional disguise cosmetics to impersonate guards, nobles, or commoners.',
        properties: [
          'Adds proficiency to checks made to create a visual disguise.',
          'Weight: 3 lbs.',
          'Cost: 25 gp.',
        ],
      ),
    ),
    MagicItem(
      id: 'forgery_kit',
      name: 'Forgery Kit',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['tools', 'deception', 'forgery', 'documents'],
      rules2014: ItemEditionDetails(
        summary: 'Includes varied parchment blanks, specialty inks, wax seals, stamps, and fine pens for counterfeiting documents.',
        description: 'A discreet case with chemicals and tools for faking royal passes and signatures.',
        properties: [
          'Weight: 5 lbs.',
          'Cost: 15 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Includes varied parchment blanks, specialty inks, wax seals, stamps, and fine pens for counterfeiting documents.',
        description: 'A discreet case with chemicals and tools for faking royal passes and signatures.',
        properties: [
          'Weight: 5 lbs.',
          'Cost: 15 gp.',
        ],
      ),
    ),
    MagicItem(
      id: 'gaming_set_dice',
      name: 'Gaming Set (Dice Set / Playing Cards / Dragonchess)',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['tools', 'gaming', 'social', 'tavern'],
      rules2014: ItemEditionDetails(
        summary: 'Dice, playing cards, Dragonchess, or Three-Dragon Ante set for gambling and passing camp downtime.',
        description: 'Recreational games popular across tavern halls and adventuring camps.',
        properties: [
          'Weight: negligible–½ lb.',
          'Cost: 1 sp–1 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Dice, playing cards, Dragonchess, or Three-Dragon Ante set for gambling and passing camp downtime.',
        description: 'Recreational games popular across tavern halls and adventuring camps.',
        properties: [
          'Weight: negligible–½ lb.',
          'Cost: 1 sp–1 gp.',
        ],
      ),
    ),
    MagicItem(
      id: 'glassblowers_tools',
      name: 'Glassblower\'s Tools',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['tools', 'crafting', 'glass', 'artisan'],
      rules2014: ItemEditionDetails(
        summary: 'Includes a blowpipe, marver block, tongs, jacks, and shears for shaping molten glass into vials and lenses.',
        description: 'Equipment for crafting glass bottles, laboratory flasks, and optical mirrors.',
        properties: [
          'Weight: 5 lbs.',
          'Cost: 30 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Includes a blowpipe, marver block, tongs, jacks, and shears for shaping molten glass into vials and lenses.',
        description: 'Equipment for crafting glass bottles, laboratory flasks, and optical mirrors.',
        properties: [
          'Weight: 5 lbs.',
          'Cost: 30 gp.',
        ],
      ),
    ),
    MagicItem(
      id: 'herbalism_kit',
      name: 'Herbalism Kit',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['tools', 'herbalism', 'potions', 'healing', 'sustain'],
      rules2014: ItemEditionDetails(
        summary: 'Includes pouches, clippers, mortar and pestle, and plant guides. Required for crafting Potions of Healing and Antitoxin.',
        description: 'Essential field botany equipment for harvesting medicinal herbs in the wild.',
        properties: [
          'Required for crafting Antitoxins and Potions of Healing.',
          'Weight: 3 lbs.',
          'Cost: 5 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Includes pouches, clippers, mortar and pestle, and plant guides. Required for crafting Potions of Healing and Antitoxin.',
        description: 'Essential field botany equipment for harvesting medicinal herbs in the wild.',
        properties: [
          'Required for crafting Antitoxins and Potions of Healing.',
          'Weight: 3 lbs.',
          'Cost: 5 gp.',
        ],
      ),
    ),
    MagicItem(
      id: 'jewelers_tools',
      name: 'Jeweler\'s Tools',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['tools', 'crafting', 'gems', 'jewelry'],
      rules2014: ItemEditionDetails(
        summary: 'Includes small saws, files, pliers, tweezers, jeweler\'s loupe, and jewel clamps for gem-cutting and goldsmithing.',
        description: 'Precision gem-crafting instruments for setting precious stones and assessing jewel worth.',
        properties: [
          'Weight: 2 lbs.',
          'Cost: 25 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Includes small saws, files, pliers, tweezers, jeweler\'s loupe, and jewel clamps for gem-cutting and goldsmithing.',
        description: 'Precision gem-crafting instruments for setting precious stones and assessing jewel worth.',
        properties: [
          'Weight: 2 lbs.',
          'Cost: 25 gp.',
        ],
      ),
    ),
    MagicItem(
      id: 'leatherworkers_tools',
      name: 'Leatherworker\'s Tools',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['tools', 'crafting', 'leather', 'armor'],
      rules2014: ItemEditionDetails(
        summary: 'Includes leather knives, punches, groover, stitching needles, and burnishers for making and repairing leather armor and bags.',
        description: 'Crafting kit for tanning hides, tailoring leather armor, and saddlery.',
        properties: [
          'Weight: 5 lbs.',
          'Cost: 5 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Includes leather knives, punches, groover, stitching needles, and burnishers for making and repairing leather armor and bags.',
        description: 'Crafting kit for tanning hides, tailoring leather armor, and saddlery.',
        properties: [
          'Weight: 5 lbs.',
          'Cost: 5 gp.',
        ],
      ),
    ),
    MagicItem(
      id: 'masons_tools',
      name: 'Mason\'s Tools',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['tools', 'crafting', 'stone', 'construction'],
      rules2014: ItemEditionDetails(
        summary: 'Includes a trowel, stone hammer, chisels, plumb line, and level for stonecarving and stone wall analysis.',
        description: 'Tools for inspecting ancient stone architecture and carving masonry passages.',
        properties: [
          'Weight: 8 lbs.',
          'Cost: 10 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Includes a trowel, stone hammer, chisels, plumb line, and level for stonecarving and stone wall analysis.',
        description: 'Tools for inspecting ancient stone architecture and carving masonry passages.',
        properties: [
          'Weight: 8 lbs.',
          'Cost: 10 gp.',
        ],
      ),
    ),
    MagicItem(
      id: 'musical_instrument_lute',
      name: 'Musical Instrument (Lute / Flute / Drum / Horn / Lyre / Bagpipes)',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['tools', 'bard', 'music', 'performance', 'focus'],
      rules2014: ItemEditionDetails(
        summary: 'Bards can use a musical instrument as a spellcasting focus for their bard spells.',
        description: 'Masterwork instrument crafted from cured tonewoods, brass, or stretched vellum.',
        properties: [
          'Serves as a spellcasting focus for Bards.',
          'Weight: 2–6 lbs.',
          'Cost: 2–35 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Bards can use a musical instrument as a spellcasting focus for their bard spells.',
        description: 'Masterwork instrument crafted from cured tonewoods, brass, or stretched vellum.',
        properties: [
          'Serves as a spellcasting focus for Bards.',
          'Weight: 2–6 lbs.',
          'Cost: 2–35 gp.',
        ],
      ),
    ),
    MagicItem(
      id: 'navigators_tools',
      name: 'Navigator\'s Tools',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['tools', 'navigation', 'sea', 'exploration'],
      rules2014: ItemEditionDetails(
        summary: 'Includes a sextant, compass, calipers, astrolabe, and nautical charts for navigating on oceans and uncharted lands.',
        description: 'Essential navigational instruments for plotting coordinates by the sun and stars.',
        properties: [
          'Weight: 2 lbs.',
          'Cost: 25 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Includes a sextant, compass, calipers, astrolabe, and nautical charts for navigating on oceans and uncharted lands.',
        description: 'Essential navigational instruments for plotting coordinates by the sun and stars.',
        properties: [
          'Weight: 2 lbs.',
          'Cost: 25 gp.',
        ],
      ),
    ),
    MagicItem(
      id: 'painters_supplies',
      name: 'Painter\'s Supplies',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['tools', 'crafting', 'art', 'canvas'],
      rules2014: ItemEditionDetails(
        summary: 'Includes an easel, brushes, canvas panels, palette, and pigment jars for portraiture and landscape depiction.',
        description: 'Fine art supplies for copying visual depictions and capturing likenesses.',
        properties: [
          'Weight: 5 lbs.',
          'Cost: 10 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Includes an easel, brushes, canvas panels, palette, and pigment jars for portraiture and landscape depiction.',
        description: 'Fine art supplies for copying visual depictions and capturing likenesses.',
        properties: [
          'Weight: 5 lbs.',
          'Cost: 10 gp.',
        ],
      ),
    ),
    MagicItem(
      id: 'poisoners_kit',
      name: 'Poisoner\'s Kit',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['tools', 'poison', 'alchemy', 'stealth'],
      damageAccent: DamageAccent.poison,
      rules2014: ItemEditionDetails(
        summary: 'Includes glass vials, mortar and pestle, pipettes, and toxic plant/mineral extracts for brewing poisons safely.',
        description: 'Specialized apparatus to distill venoms without poisoning oneself.',
        properties: [
          'Required for harvesting and brewing specialized poisons.',
          'Weight: 2 lbs.',
          'Cost: 50 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Includes glass vials, mortar and pestle, pipettes, and toxic plant/mineral extracts for brewing poisons safely.',
        description: 'Specialized apparatus to distill venoms without poisoning oneself.',
        properties: [
          'Required for harvesting and brewing specialized poisons.',
          'Weight: 2 lbs.',
          'Cost: 50 gp.',
        ],
      ),
    ),
    MagicItem(
      id: 'potters_tools',
      name: 'Potter\'s Tools',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['tools', 'crafting', 'clay', 'ceramic'],
      rules2014: ItemEditionDetails(
        summary: 'Includes potter\'s ribs, scrapers, wire clay cutter, and trimming loops for shaping pottery vessels.',
        description: 'Tools for sculpting ceramic urns, jugs, and amphorae.',
        properties: [
          'Weight: 3 lbs.',
          'Cost: 10 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Includes potter\'s ribs, scrapers, wire clay cutter, and trimming loops for shaping pottery vessels.',
        description: 'Tools for sculpting ceramic urns, jugs, and amphorae.',
        properties: [
          'Weight: 3 lbs.',
          'Cost: 10 gp.',
        ],
      ),
    ),
    MagicItem(
      id: 'smiths_tools',
      name: 'Smith\'s Tools',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['tools', 'crafting', 'blacksmithing', 'metal', 'weapons', 'armor'],
      rules2014: ItemEditionDetails(
        summary: 'Includes hammers, tongs, chisels, files, and aprons for forging and repairing metal weapons and armor at a forge.',
        description: 'Heavy forge implements for blacksmithing and weapon repair.',
        properties: [
          'Weight: 8 lbs.',
          'Cost: 20 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Includes hammers, tongs, chisels, files, and aprons for forging and repairing metal weapons and armor at a forge.',
        description: 'Heavy forge implements for blacksmithing and weapon repair.',
        properties: [
          'Weight: 8 lbs.',
          'Cost: 20 gp.',
        ],
      ),
    ),
    MagicItem(
      id: 'tinkers_tools',
      name: 'Tinker\'s Tools',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['tools', 'crafting', 'repair', 'devices', 'clockwork'],
      rules2014: ItemEditionDetails(
        summary: 'Includes fine saws, pliers, solder, brazing tools, wire, and miniature gears for fixing small metal objects and clockwork.',
        description: 'A versatile toolkit for repairing lanterns, pots, hinges, and clockwork mechanisms.',
        properties: [
          'Weight: 10 lbs.',
          'Cost: 50 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Includes fine saws, pliers, solder, brazing tools, wire, and miniature gears for fixing small metal objects and clockwork.',
        description: 'A versatile toolkit for repairing lanterns, pots, hinges, and clockwork mechanisms.',
        properties: [
          'Weight: 10 lbs.',
          'Cost: 50 gp.',
        ],
      ),
    ),
    MagicItem(
      id: 'weavers_tools',
      name: 'Weaver\'s Tools',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['tools', 'crafting', 'textiles', 'cloth'],
      rules2014: ItemEditionDetails(
        summary: 'Includes shuttles, combs, scissors, needles, and a portable lap loom for weaving textiles and repairing tapestries.',
        description: 'Equipment for spinning yarn and repairing cloaks, ropes, and tents.',
        properties: [
          'Weight: 5 lbs.',
          'Cost: 1 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Includes shuttles, combs, scissors, needles, and a portable lap loom for weaving textiles and repairing tapestries.',
        description: 'Equipment for spinning yarn and repairing cloaks, ropes, and tents.',
        properties: [
          'Weight: 5 lbs.',
          'Cost: 1 gp.',
        ],
      ),
    ),
    MagicItem(
      id: 'woodcarvers_tools',
      name: 'Woodcarver\'s Tools',
      category: ItemCategory.adventuringGear,
      rarity: ItemRarity.nonmagical,
      requiresAttunement: false,
      tags: ['tools', 'crafting', 'woodcarving', 'arrows', 'wands'],
      rules2014: ItemEditionDetails(
        summary: 'Includes whittling knives, gouges, rasps, and sandpaper for carving wooden icons, wands, and crafting arrows.',
        description: 'Precision carving knives for crafting arrows, arcane foci, and figurines.',
        properties: [
          'Weight: 5 lbs.',
          'Cost: 1 gp.',
        ],
      ),
      rules2024: ItemEditionDetails(
        summary: 'Includes whittling knives, gouges, rasps, and sandpaper for carving wooden icons, wands, and crafting arrows.',
        description: 'Precision carving knives for crafting arrows, arcane foci, and figurines.',
        properties: [
          'Weight: 5 lbs.',
          'Cost: 1 gp.',
        ],
      ),
    ),
  ];
}
