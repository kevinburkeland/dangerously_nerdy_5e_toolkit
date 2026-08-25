import 'rollable_table.dart';

/// Complete 5e SRD Magic, Chaos, and Spell Resolution tables.
class SrdMagicTables {
  SrdMagicTables._();

  // ==========================================
  // WILD MAGIC SURGE (d100)
  // ==========================================
  static const RollableTable wildMagicSurge = RollableTable(
    id: 'wild_magic_surge',
    name: 'Wild Magic Surge',
    category: TableCategory.magic,
    diceFormula: '1d100',
    description: 'When a Wild Magic sorcerer casts a spell of 1st level or higher, roll on this table to unleash chaotic magic surges.',
    entries: [
      TableEntry(minRoll: 1, maxRoll: 2, label: 'Roll on this table every turn', description: 'Roll on this table at the start of each of your turns for the next minute, ignoring this result on subsequent rolls.'),
      TableEntry(minRoll: 3, maxRoll: 4, label: 'See invisible creatures', description: 'For the next minute, you can see any invisible creature if you have line of sight to it.'),
      TableEntry(minRoll: 5, maxRoll: 6, label: 'Modron appears', description: 'A modron chosen and controlled by the DM appears in an unoccupied space within 5 feet of you, then disappears 1 minute later.'),
      TableEntry(minRoll: 7, maxRoll: 8, label: 'Fireball centered on self', description: 'You cast Fireball as a 3rd-level spell centered on yourself.'),
      TableEntry(minRoll: 9, maxRoll: 10, label: 'Magic Missile cascade', description: 'You cast Magic Missile as a 5th-level spell.'),
      TableEntry(minRoll: 11, maxRoll: 12, label: 'Random height change', description: 'Roll a d10. Your height changes by a number of inches equal to the roll. If the roll is odd, you shrink. If the roll is even, you grow.'),
      TableEntry(minRoll: 13, maxRoll: 14, label: 'Confusion centered on self', description: 'You cast Confusion centered on yourself.'),
      TableEntry(minRoll: 15, maxRoll: 16, label: 'Regain 5 HP per turn', description: 'For the next minute, you regain 5 hit points at the start of each of your turns.'),
      TableEntry(minRoll: 17, maxRoll: 18, label: 'Grow a feather beard', description: 'You grow a long beard made of feathers that remains until you sneeze, at which point the feathers explode off your face.'),
      TableEntry(minRoll: 19, maxRoll: 20, label: 'Grease centered on self', description: 'You cast Grease centered on yourself.'),
      TableEntry(minRoll: 21, maxRoll: 22, label: 'Spell targets disadvantage saves', description: 'Creatures have disadvantage on saving throws against the next spell you cast in the next minute that involves a save.'),
      TableEntry(minRoll: 23, maxRoll: 24, label: 'Skin turns vibrant blue', description: 'Your skin turns a vibrant shade of blue. A Remove Curse spell can end this effect.'),
      TableEntry(minRoll: 25, maxRoll: 26, label: 'Third eye with advantage', description: 'An eye appears on your forehead for the next minute. During that time, you have advantage on Wisdom (Perception) checks that rely on sight.'),
      TableEntry(minRoll: 27, maxRoll: 28, label: 'Bonus action casting', description: 'For the next minute, all your spells with a casting time of 1 action have a casting time of 1 bonus action.'),
      TableEntry(minRoll: 29, maxRoll: 30, label: 'Teleport up to 60 feet', description: 'You teleport up to 60 feet to an unoccupied space of your choice that you can see.'),
      TableEntry(minRoll: 31, maxRoll: 32, label: 'Astral Plane transition', description: 'You are transported to the Astral Plane until the end of your next turn, after which you return to the space you previously occupied.'),
      TableEntry(minRoll: 33, maxRoll: 34, label: 'Maximize damage next minute', description: 'Maximize the damage of the next damaging spell you cast within the next minute.'),
      TableEntry(minRoll: 35, maxRoll: 36, label: 'Random age shift', description: 'Roll a d10. Your age changes by a number of years equal to the roll. If the roll is odd, you get younger (min 1). If even, you get older.'),
      TableEntry(minRoll: 37, maxRoll: 38, label: 'Flumph companions', description: '1d6 flumphs controlled by the DM appear in unoccupied spaces within 60 feet of you and are frightened of you. They vanish after 1 minute.'),
      TableEntry(minRoll: 39, maxRoll: 40, label: 'Regain 2d10 hit points', description: 'You regain 2d10 hit points.'),
      TableEntry(minRoll: 41, maxRoll: 42, label: 'Turn into a potted plant', description: 'You turn into a potted plant until the start of your next turn. While a plant, you are incapacitated and have vulnerability to all damage.'),
      TableEntry(minRoll: 43, maxRoll: 44, label: 'Teleport bonus action', description: 'For the next minute, you can teleport up to 20 feet as a bonus action on each of your turns.'),
      TableEntry(minRoll: 45, maxRoll: 46, label: 'Levitate on self', description: 'You cast Levitate on yourself.'),
      TableEntry(minRoll: 47, maxRoll: 48, label: 'Unicorn ally appears', description: 'A unicorn controlled by the DM appears in a space within 5 feet of you, then disappears 1 minute later.'),
      TableEntry(minRoll: 49, maxRoll: 50, label: 'Can\'t speak without pink bubbles', description: 'You can\'t speak for the next minute. Whenever you try, pink bubbles float out of your mouth.'),
      TableEntry(minRoll: 51, maxRoll: 52, label: 'Spectral shield +2 AC', description: 'A spectral shield hovers near you for the next minute, granting you a +2 bonus to AC and immunity to Magic Missile.'),
      TableEntry(minRoll: 53, maxRoll: 54, label: 'Immunity to alcohol for 5d6 days', description: 'You are immune to being intoxicated by alcohol for the next 5d6 days.'),
      TableEntry(minRoll: 55, maxRoll: 56, label: 'Hair falls out then grows back', description: 'Your hair falls out but grows back within 24 hours.'),
      TableEntry(minRoll: 57, maxRoll: 58, label: 'Flaming touch for 1 minute', description: 'For the next minute, any flammable object you touch that isn\'t being worn or carried by another creature bursts into flame.'),
      TableEntry(minRoll: 59, maxRoll: 60, label: 'Regain lowest spent spell slot', description: 'You regain your lowest-level expended spell slot.'),
      TableEntry(minRoll: 61, maxRoll: 62, label: 'Shout when speaking for 1 minute', description: 'For the next minute, you must shout when you speak.'),
      TableEntry(minRoll: 63, maxRoll: 64, label: 'Fog Cloud centered on self', description: 'You cast Fog Cloud centered on yourself.'),
      TableEntry(minRoll: 65, maxRoll: 66, label: 'Lightning arcs to 3 creatures', description: 'Up to three creatures you choose within 30 feet of you take 4d10 lightning damage.'),
      TableEntry(minRoll: 67, maxRoll: 68, label: 'Frightened of nearest creature', description: 'You are frightened by the nearest creature until the end of your next turn.'),
      TableEntry(minRoll: 69, maxRoll: 70, label: 'Invisibility and silence for 1 min', description: 'Each creature within 30 feet of you becomes invisible for the next minute. The invisibility ends on a creature when it attacks or casts a spell.'),
      TableEntry(minRoll: 71, maxRoll: 72, label: 'Resistance to all damage', description: 'You gain resistance to all damage for the next minute.'),
      TableEntry(minRoll: 73, maxRoll: 74, label: 'Random creature poisoned for 1d4 hr', description: 'A random creature within 60 feet of you becomes poisoned for 1d4 hours.'),
      TableEntry(minRoll: 75, maxRoll: 76, label: 'Glow with bright light (30 ft)', description: 'You glow with bright light in a 30-foot radius for the next minute. Any creature that ends its turn within 5 feet of you is blinded until the end of its next turn.'),
      TableEntry(minRoll: 77, maxRoll: 78, label: 'Polymorph on self into sheep', description: 'You cast Polymorph on yourself. If you fail the saving throw, you turn into a sheep for the spell\'s duration.'),
      TableEntry(minRoll: 79, maxRoll: 80, label: 'Illusory butterflies and petals', description: 'Illusory butterflies and flower petals flutter in the air within 10 feet of you for the next minute.'),
      TableEntry(minRoll: 81, maxRoll: 82, label: 'Take one additional action now', description: 'You can take one additional action immediately on this turn.'),
      TableEntry(minRoll: 83, maxRoll: 84, label: 'Necrotic burst to nearby creatures', description: 'Each creature within 30 feet of you takes 1d10 necrotic damage. You regain hit points equal to the total necrotic damage dealt.'),
      TableEntry(minRoll: 85, maxRoll: 86, label: 'Mirror Image on self', description: 'You cast Mirror Image on yourself.'),
      TableEntry(minRoll: 87, maxRoll: 88, label: 'Fly speed 60 ft on random creature', description: 'You cast Fly on a random creature within 60 feet of you.'),
      TableEntry(minRoll: 89, maxRoll: 90, label: 'Become invisible and silent', description: 'You become invisible for the next minute. During that time, other creatures can\'t hear you. The invisibility ends if you attack or cast a spell.'),
      TableEntry(minRoll: 91, maxRoll: 92, label: 'Reincarnate if you die in 1 min', description: 'If you die within the next minute, you immediately come back to life as if by the Reincarnate spell.'),
      TableEntry(minRoll: 93, maxRoll: 94, label: 'Size increases by one category', description: 'Your size increases by one size category for the next minute (as the Enlarge effect of Enlarge/Reduce).'),
      TableEntry(minRoll: 95, maxRoll: 96, label: 'Vulnerability to piercing damage', description: 'You and all creatures within 30 feet of you gain vulnerability to piercing damage for the next minute.'),
      TableEntry(minRoll: 97, maxRoll: 98, label: 'Surrounded by faint ethereal music', description: 'You are surrounded by faint, ethereal music for the next minute.'),
      TableEntry(minRoll: 99, maxRoll: 100, label: 'Regain all expended sorcery points', description: 'You regain all expended sorcery points.'),
    ],
  );

  // ==========================================
  // CONFUSION SPELL BEHAVIOR (d10)
  // ==========================================
  static const RollableTable confusionBehavior = RollableTable(
    id: 'confusion_behavior',
    name: 'Confusion Spell Behavior',
    category: TableCategory.magic,
    diceFormula: '1d10',
    diceSides: 10,
    description: 'An affected target must roll a d10 at the start of each of its turns to determine its chaotic behavior.',
    entries: [
      TableEntry(minRoll: 1, maxRoll: 1, label: 'Move in random direction', description: 'The creature uses all its movement to move in a random direction (1d8 for direction). It doesn\'t take an action this turn.'),
      TableEntry(minRoll: 2, maxRoll: 2, label: 'Do nothing', description: 'The creature doesn\'t move or take actions this turn.'),
      TableEntry(minRoll: 3, maxRoll: 7, label: 'Attack nearest creature', description: 'The creature uses its action to make a melee attack against a randomly determined creature within its reach. If no creature is within reach, it does nothing.'),
      TableEntry(minRoll: 8, maxRoll: 10, label: 'Act normally', description: 'The creature can act and move normally for this turn.'),
    ],
  );

  // ==========================================
  // REINCARNATE RACE (d100)
  // ==========================================
  static const RollableTable reincarnateRace = RollableTable(
    id: 'reincarnate_race',
    name: 'Reincarnate Race Table',
    category: TableCategory.magic,
    diceFormula: '1d100',
    description: 'When the Reincarnate spell touches a dead humanoid, the magic forms a new adult body rolling on this table.',
    entries: [
      TableEntry(minRoll: 1, maxRoll: 4, label: 'Dragonborn', description: 'Draconic ancestry, Breath Weapon, and Damage Resistance.'),
      TableEntry(minRoll: 5, maxRoll: 13, label: 'Dwarf, Hill', description: 'Dwarven Toughness, Darkvision, Poison Resilience.'),
      TableEntry(minRoll: 14, maxRoll: 21, label: 'Dwarf, Mountain', description: 'Dwarven Armor Training, +2 Strength, +2 Constitution.'),
      TableEntry(minRoll: 22, maxRoll: 25, label: 'Elf, Dark (Drow)', description: 'Superior Darkvision (120 ft), Sunlight Sensitivity, Drow Magic.'),
      TableEntry(minRoll: 26, maxRoll: 34, label: 'Elf, High', description: 'Wizard Cantrip, Keen Senses, Fey Ancestry, Extra Language.'),
      TableEntry(minRoll: 35, maxRoll: 42, label: 'Elf, Wood', description: 'Fleet of Foot (35 ft speed), Mask of the Wild, Keen Senses.'),
      TableEntry(minRoll: 43, maxRoll: 46, label: 'Gnome, Forest', description: 'Natural Illusionist (Minor Illusion), Speak with Small Beasts.'),
      TableEntry(minRoll: 47, maxRoll: 52, label: 'Gnome, Rock', description: 'Artificer\'s Lore, Tinker Clockwork Devices.'),
      TableEntry(minRoll: 53, maxRoll: 56, label: 'Half-Elf', description: 'Fey Ancestry, Skill Versatility (2 bonus skills), Charisma +2.'),
      TableEntry(minRoll: 57, maxRoll: 60, label: 'Half-Orc', description: 'Relentless Endurance, Savage Attacks (+1 crit die), Darkvision.'),
      TableEntry(minRoll: 61, maxRoll: 68, label: 'Halfling, Lightfoot', description: 'Naturally Stealthy (hide behind Medium creatures), Lucky, Brave.'),
      TableEntry(minRoll: 69, maxRoll: 76, label: 'Halfling, Stout', description: 'Stout Resilience (poison advantage & resistance), Lucky, Brave.'),
      TableEntry(minRoll: 77, maxRoll: 96, label: 'Human', description: '+1 to All Ability Scores or Variant Feat & Skill.'),
      TableEntry(minRoll: 97, maxRoll: 100, label: 'Tiefling', description: 'Hellish Resistance (fire), Darkvision, Infernal Legacy Thaumaturgy.'),
    ],
  );

  // ==========================================
  // TELEPORTATION MISHAP / FAMILIARITY (d100)
  // ==========================================
  static const RollableTable teleportationMishap = RollableTable(
    id: 'teleportation_mishap',
    name: 'Teleportation Mishap Table',
    category: TableCategory.magic,
    diceFormula: '1d100',
    description: 'Roll d100 based on familiarity to resolve destination accuracy and teleport mishaps.',
    entries: [
      TableEntry(minRoll: 1, maxRoll: 5, label: 'Mishap (3d10 Force Damage)', description: 'The spell\'s teleportation magic goes awry. Each teleporting creature takes 3d10 force damage, and the DM rerolls on the table.'),
      TableEntry(minRoll: 6, maxRoll: 13, label: 'Similar Area', description: 'You and your group appear in a location that is visually or thematically similar to the target area.'),
      TableEntry(minRoll: 14, maxRoll: 24, label: 'Off Target', description: 'You appear 1d10 × 1d10 percent of the distance traveled away from your destination in a random 1d8 direction.'),
      TableEntry(minRoll: 25, maxRoll: 100, label: 'On Target', description: 'You and your group appear precisely where you intended.'),
    ],
  );

  // ==========================================
  // PRISMATIC SPRAY (d8)
  // ==========================================
  static const RollableTable prismaticSpray = RollableTable(
    id: 'prismatic_spray',
    name: 'Prismatic Spray & Wall Beams',
    category: TableCategory.magic,
    diceFormula: '1d8',
    diceSides: 8,
    description: 'Roll a d8 for each target in the 60-foot cone to determine which colored ray affects it.',
    entries: [
      TableEntry(minRoll: 1, maxRoll: 1, label: '1. Red (Fire)', description: '10d6 fire damage on failed Dexterity save (half on success).'),
      TableEntry(minRoll: 2, maxRoll: 2, label: '2. Orange (Acid)', description: '10d6 acid damage on failed Dexterity save (half on success).'),
      TableEntry(minRoll: 3, maxRoll: 3, label: '3. Yellow (Lightning)', description: '10d6 lightning damage on failed Dexterity save (half on success).'),
      TableEntry(minRoll: 4, maxRoll: 4, label: '4. Green (Poison)', description: '10d6 poison damage on failed Constitution save (half on success).'),
      TableEntry(minRoll: 5, maxRoll: 5, label: '5. Blue (Cold)', description: '10d6 cold damage on failed Dexterity save (half on success).'),
      TableEntry(minRoll: 6, maxRoll: 6, label: '6. Indigo (Restrained / Petrified)', description: 'On failed Con save, creature is restrained and begins turning to stone. 3 failed saves = petrified.'),
      TableEntry(minRoll: 7, maxRoll: 7, label: '7. Violet (Blinded / Plane Shifted)', description: 'On failed Wis save, creature is blinded and transported to another plane of existence.'),
      TableEntry(minRoll: 8, maxRoll: 8, label: '8. Special (Struck by Two Rays)', description: 'Roll twice on this table, ignoring rolls of 8.'),
    ],
  );

  // ==========================================
  // ROD OF WONDER (d100)
  // ==========================================
  static const RollableTable rodOfWonder = RollableTable(
    id: 'rod_of_wonder',
    name: 'Rod of Wonder Effects',
    category: TableCategory.magic,
    diceFormula: '1d100',
    description: 'Point the rod at a target and expend 1 charge to generate a random magical manifestation.',
    entries: [
      TableEntry(minRoll: 1, maxRoll: 5, label: 'Cast Slow', description: 'You cast Slow on the target creature.'),
      TableEntry(minRoll: 6, maxRoll: 10, label: 'Cast Faerie Fire', description: 'You cast Faerie Fire centered on the target.'),
      TableEntry(minRoll: 11, maxRoll: 15, label: 'You are stunned until start of next turn', description: 'Ethereal music distracts you; you are stunned.'),
      TableEntry(minRoll: 16, maxRoll: 20, label: 'Cast Gust of Wind', description: 'You cast Gust of Wind toward the target.'),
      TableEntry(minRoll: 21, maxRoll: 25, label: 'Target skin turns blue', description: 'Target skin turns radiant blue for 1d10 days.'),
      TableEntry(minRoll: 26, maxRoll: 30, label: 'Cast Darkness', description: 'You cast Darkness on a point within 60 feet.'),
      TableEntry(minRoll: 31, maxRoll: 35, label: 'Grass grows in 60-foot area', description: 'Lush 10-foot tall grass bursts from the ground and wilts after 1 minute.'),
      TableEntry(minRoll: 36, maxRoll: 40, label: 'Target is turned into a stone statue', description: 'Target must succeed on DC 15 Con save or be petrified for 1 hour.'),
      TableEntry(minRoll: 41, maxRoll: 45, label: '600 large butterflies burst forth', description: 'A swarm of colorful butterflies blinds everyone within 30 feet for 1d4 rounds.'),
      TableEntry(minRoll: 46, maxRoll: 50, label: 'Cast Enlarge/Reduce on target', description: 'Enlarges target on even, reduces on odd.'),
      TableEntry(minRoll: 51, maxRoll: 53, label: 'Cast Fireball (8d6 fire)', description: 'You cast Fireball as a 3rd-level spell at the target.'),
      TableEntry(minRoll: 54, maxRoll: 58, label: 'Heavy rain falls in a 60-foot radius', description: 'A deluge of rain douses all mundane flames.'),
      TableEntry(minRoll: 59, maxRoll: 62, label: 'Leaves sprout from target', description: 'Target sprouts autumn oak leaves for 24 hours.'),
      TableEntry(minRoll: 63, maxRoll: 65, label: 'Cast Lightning Bolt (8d6 lightning)', description: 'You cast Lightning Bolt in a 100-foot line.'),
      TableEntry(minRoll: 66, maxRoll: 69, label: 'Stream of 1d4 × 10 gems shoot forth', description: 'Each gem is worth 1 gp and deals 1 bludgeoning damage to target.'),
      TableEntry(minRoll: 70, maxRoll: 79, label: 'Cloud of shimmering mist blinds area', description: 'Obscures vision in a 20-foot radius sphere for 1 minute.'),
      TableEntry(minRoll: 80, maxRoll: 84, label: 'Target becomes invisible for 1 minute', description: 'You cast Invisibility on the target.'),
      TableEntry(minRoll: 85, maxRoll: 87, label: 'Heavy wind blows all creatures 10 ft away', description: 'Hurricane gusts force creatures back 10 feet.'),
      TableEntry(minRoll: 88, maxRoll: 90, label: 'Target is levitated into air', description: 'Target is levitated 20 feet up for 1 minute.'),
      TableEntry(minRoll: 91, maxRoll: 95, label: 'You cast Flesh to Stone', description: 'Target must make DC 15 Con save or begin petrifying.'),
      TableEntry(minRoll: 96, maxRoll: 97, label: 'You cast Polymorph on target', description: 'Target fails save -> polymorphed into a harmless frog.'),
      TableEntry(minRoll: 98, maxRoll: 100, label: 'Target takes 10d6 force damage', description: 'A devastating shockwave strikes the target.'),
    ],
  );

  // ==========================================
  // BAG OF TRICKS CREATURES (d8)
  // ==========================================
  static const RollableTable bagOfTricksGray = RollableTable(
    id: 'bag_of_tricks_gray',
    name: 'Bag of Tricks (Gray)',
    category: TableCategory.magic,
    diceFormula: '1d8',
    diceSides: 8,
    description: 'Reach into the bag, pull out a fuzzy object, and throw it up to 20 feet to transform into a beast.',
    entries: [
      TableEntry(minRoll: 1, maxRoll: 1, label: 'Weasel (CR 0)', description: 'Tiny beast, AC 13, HP 1, +5 stealth.'),
      TableEntry(minRoll: 2, maxRoll: 2, label: 'Giant Rat (CR 1/8)', description: 'Small beast, AC 12, HP 7, Pack Tactics.'),
      TableEntry(minRoll: 3, maxRoll: 3, label: 'Badger (CR 0)', description: 'Tiny beast, AC 10, HP 3, Keen Smell.'),
      TableEntry(minRoll: 4, maxRoll: 4, label: 'Boar (CR 1/4)', description: 'Medium beast, AC 11, HP 11, Charge, Relentless.'),
      TableEntry(minRoll: 5, maxRoll: 5, label: 'Panther (CR 1/4)', description: 'Medium beast, AC 12, HP 13, Pounce, Keen Smell.'),
      TableEntry(minRoll: 6, maxRoll: 6, label: 'Giant Badger (CR 1/4)', description: 'Medium beast, AC 10, HP 13, Multiattack.'),
      TableEntry(minRoll: 7, maxRoll: 7, label: 'Dire Wolf (CR 1)', description: 'Large beast, AC 14, HP 37, Pack Tactics, Bite DC 13 prone.'),
      TableEntry(minRoll: 8, maxRoll: 8, label: 'Giant Elk (CR 2)', description: 'Huge beast, AC 14, HP 42, Charge, Hooves DC 14 prone.'),
    ],
  );

  static const RollableTable bagOfTricksRust = RollableTable(
    id: 'bag_of_tricks_rust',
    name: 'Bag of Tricks (Rust)',
    category: TableCategory.magic,
    diceFormula: '1d8',
    diceSides: 8,
    description: 'Reach into the rust bag to throw and spawn an animal ally.',
    entries: [
      TableEntry(minRoll: 1, maxRoll: 1, label: 'Rat (CR 0)', description: 'Tiny beast, AC 10, HP 1.'),
      TableEntry(minRoll: 2, maxRoll: 2, label: 'Owl (CR 0)', description: 'Tiny beast, AC 11, HP 1, Flyby, Darkvision.'),
      TableEntry(minRoll: 3, maxRoll: 3, label: 'Mastiff (CR 1/8)', description: 'Medium beast, AC 12, HP 5, Bite DC 11 prone.'),
      TableEntry(minRoll: 4, maxRoll: 4, label: 'Goat (CR 0)', description: 'Medium beast, AC 10, HP 4, Sure-Footed.'),
      TableEntry(minRoll: 5, maxRoll: 5, label: 'Giant Goat (CR 1/2)', description: 'Large beast, AC 11, HP 19, Charge 2d4+3.'),
      TableEntry(minRoll: 6, maxRoll: 6, label: 'Giant Boar (CR 2)', description: 'Large beast, AC 12, HP 42, Relentless.'),
      TableEntry(minRoll: 7, maxRoll: 7, label: 'Lion (CR 1)', description: 'Large beast, AC 12, HP 26, Pack Tactics, Pounce.'),
      TableEntry(minRoll: 8, maxRoll: 8, label: 'Brown Bear (CR 1)', description: 'Large beast, AC 11, HP 34, Multiattack.'),
    ],
  );

  static const RollableTable bagOfTricksTan = RollableTable(
    id: 'bag_of_tricks_tan',
    name: 'Bag of Tricks (Tan)',
    category: TableCategory.magic,
    diceFormula: '1d8',
    diceSides: 8,
    description: 'Reach into the tan bag to throw and spawn a ferocious beast companion.',
    entries: [
      TableEntry(minRoll: 1, maxRoll: 1, label: 'Jackal (CR 0)', description: 'Small beast, AC 12, HP 3, Pack Tactics.'),
      TableEntry(minRoll: 2, maxRoll: 2, label: 'Ape (CR 1/2)', description: 'Medium beast, AC 12, HP 19, Multiattack, Rock throw.'),
      TableEntry(minRoll: 3, maxRoll: 3, label: 'Baboon (CR 0)', description: 'Small beast, AC 12, HP 3, Pack Tactics.'),
      TableEntry(minRoll: 4, maxRoll: 4, label: 'Axe Beak (CR 1/4)', description: 'Large beast, AC 11, HP 19, 50 ft speed.'),
      TableEntry(minRoll: 5, maxRoll: 5, label: 'Black Bear (CR 1/2)', description: 'Medium beast, AC 11, HP 19, Multiattack.'),
      TableEntry(minRoll: 6, maxRoll: 6, label: 'Giant Weasel (CR 1/8)', description: 'Medium beast, AC 13, HP 9, Darkvision.'),
      TableEntry(minRoll: 7, maxRoll: 7, label: 'Giant Hyena (CR 1)', description: 'Large beast, AC 12, HP 45, Rampage bonus bite.'),
      TableEntry(minRoll: 8, maxRoll: 8, label: 'Tiger (CR 1)', description: 'Large beast, AC 12, HP 37, Pounce.'),
    ],
  );
}
