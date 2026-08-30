import 'package:flutter/foundation.dart';
import '../domain/core_types.dart';
import '../domain/homebrew_extended_entities.dart';

/// Comprehensive SRD 5.1 and 5.2 Classes Library containing all 12 core classes.
@immutable
class SrdClassesLibrary {
  static final CharacterClass barbarian = CharacterClass(
    id: const EntityId(slug: 'barbarian', ruleset: RulesetVersion.v2024),
    name: 'Barbarian',
    hitDie: 'd12',
    primaryAbility: 'Strength',
    savingThrows: const ['Strength', 'Constitution'],
    armorProficiencies: const ['Light Armor', 'Medium Armor', 'Shields'],
    weaponProficiencies: const ['Simple Weapons', 'Martial Weapons'],
    featuresMarkdown:
        '**Rage.** Gain Advantage on STR checks/saves, bonus melee damage (+2 to +4), and resistance to bludgeoning, piercing, and slashing damage.\n\n'
        '**Unarmored Defense.** When not wearing armor, AC = 10 + DEX mod + CON mod + Shield.\n\n'
        '**Reckless Attack.** Gain Advantage on melee weapon attack rolls using STR, but attack rolls against you have Advantage until your next turn.\n\n'
        '**Danger Sense.** Advantage on DEX saving throws against effects you can see.',
    customProperties: const {
      'skillChoiceCount': 2,
      'allowedSkills': [
        'animalHandling',
        'athletics',
        'intimidation',
        'nature',
        'perception',
        'survival'
      ],
    },
    subclasses: [
      Subclass(
        id: const EntityId(slug: 'path-of-the-berserker', ruleset: RulesetVersion.v2024),
        name: 'Path of the Berserker',
        classSlug: 'barbarian',
        featuresMarkdown:
            '**Frenzy.** While in a Rage, make a bonus melee attack or deal extra frenzy damage on hit.',
      ),
    ],
  );

  static final CharacterClass bard = CharacterClass(
    id: const EntityId(slug: 'bard', ruleset: RulesetVersion.v2024),
    name: 'Bard',
    hitDie: 'd8',
    primaryAbility: 'Charisma',
    savingThrows: const ['Dexterity', 'Charisma'],
    armorProficiencies: const ['Light Armor'],
    weaponProficiencies: const [
      'Simple Weapons',
      'Hand Crossbows',
      'Longswords',
      'Rapiers',
      'Shortswords'
    ],
    spellcastingAbility: 'Charisma',
    featuresMarkdown:
        '**Bardic Inspiration.** Grant an ally an inspiration die (d6-d12) to add to an attack roll, ability check, or saving throw.\n\n'
        '**Spellcasting.** Charisma-based full caster prepared spells.\n\n'
        '**Jack of All Trades.** Add half your Proficiency Bonus to any ability check that doesn\'t already include it.\n\n'
        '**Song of Rest / Restorative Rhythm.** Heal allies during Short Rests.\n\n'
        '**Expertise.** Double proficiency bonus on two chosen skills.',
    customProperties: const {
      'skillChoiceCount': 3,
      'allowedSkills': [
        'acrobatics',
        'animalHandling',
        'arcana',
        'athletics',
        'deception',
        'history',
        'insight',
        'intimidation',
        'investigation',
        'medicine',
        'nature',
        'perception',
        'performance',
        'persuasion',
        'religion',
        'sleightOfHand',
        'stealth',
        'survival'
      ],
    },
    subclasses: [
      Subclass(
        id: const EntityId(slug: 'college-of-lore', ruleset: RulesetVersion.v2024),
        name: 'College of Lore',
        classSlug: 'bard',
        featuresMarkdown:
            '**Cutting Words.** Use Reaction and Bardic Inspiration to subtract from enemy attack rolls, ability checks, or damage.',
      ),
    ],
  );

  static final CharacterClass cleric = CharacterClass(
    id: const EntityId(slug: 'cleric', ruleset: RulesetVersion.v2024),
    name: 'Cleric',
    hitDie: 'd8',
    primaryAbility: 'Wisdom',
    savingThrows: const ['Wisdom', 'Charisma'],
    armorProficiencies: const ['Light Armor', 'Medium Armor', 'Shields'],
    weaponProficiencies: const ['Simple Weapons'],
    spellcastingAbility: 'Wisdom',
    featuresMarkdown:
        '**Spellcasting.** Full divine spellcaster using Wisdom.\n\n'
        '**Channel Divinity.** Powerful divine surges (e.g. Turn Undead, Divine Spark).\n\n'
        '**Turn Undead.** Undead must flee from you on failed WIS saving throw.\n\n'
        '**Divine Intervention.** Call upon your deity for direct miraculous intervention.',
    customProperties: const {
      'skillChoiceCount': 2,
      'allowedSkills': ['history', 'insight', 'medicine', 'persuasion', 'religion'],
    },
    subclasses: [
      Subclass(
        id: const EntityId(slug: 'life-domain', ruleset: RulesetVersion.v2024),
        name: 'Life Domain',
        classSlug: 'cleric',
        featuresMarkdown:
            '**Disciple of Life.** Healing spells restore an additional 2 + spell level HP.\n\n'
            '**Preserve Life.** Channel Divinity to heal injured allies within 30 feet.',
      ),
    ],
  );

  static final CharacterClass druid = CharacterClass(
    id: const EntityId(slug: 'druid', ruleset: RulesetVersion.v2024),
    name: 'Druid',
    hitDie: 'd8',
    primaryAbility: 'Wisdom',
    savingThrows: const ['Intelligence', 'Wisdom'],
    armorProficiencies: const ['Light Armor', 'Medium Armor', 'Shields'],
    weaponProficiencies: const [
      'Clubs',
      'Daggers',
      'Darts',
      'Javelins',
      'Maces',
      'Quarterstaffs',
      'Scimitars',
      'Sickles',
      'Slings',
      'Spears'
    ],
    spellcastingAbility: 'Wisdom',
    featuresMarkdown:
        '**Spellcasting.** Nature-based full spellcaster with ritual casting.\n\n'
        '**Wild Shape.** Magically transform into the form of a beast or elemental.\n\n'
        '**Wild Companion.** Summon a familiar spirit using your Wild Shape charges.',
    customProperties: const {
      'skillChoiceCount': 2,
      'allowedSkills': [
        'arcana',
        'animalHandling',
        'insight',
        'medicine',
        'nature',
        'perception',
        'religion',
        'survival'
      ],
    },
    subclasses: [
      Subclass(
        id: const EntityId(slug: 'circle-of-the-land', ruleset: RulesetVersion.v2024),
        name: 'Circle of the Land',
        classSlug: 'druid',
        featuresMarkdown:
            '**Natural Recovery.** Regain spell slots on Short Rest.\n\n'
            '**Circle Spells.** Gain bonus domain spells based on chosen biome.',
      ),
    ],
  );

  static final CharacterClass fighter = CharacterClass(
    id: const EntityId(slug: 'fighter', ruleset: RulesetVersion.v2024),
    name: 'Fighter',
    hitDie: 'd10',
    primaryAbility: 'Strength or Dexterity',
    savingThrows: const ['Strength', 'Constitution'],
    armorProficiencies: const ['All Armor', 'Shields'],
    weaponProficiencies: const ['Simple Weapons', 'Martial Weapons'],
    featuresMarkdown:
        '**Fighting Style.** Select a specialized combat style (Archery, Defense, Dueling, Great Weapon Fighting, Two-Weapon Fighting).\n\n'
        '**Second Wind.** Bonus action to regain 1d10 + Fighter Level HP.\n\n'
        '**Action Surge.** Take an additional Action on your turn once per short or long rest.\n\n'
        '**Extra Attack.** Attack two, three, or four times whenever you take the Attack action.\n\n'
        '**Indomitable.** Reroll a failed saving throw.',
    customProperties: const {
      'skillChoiceCount': 2,
      'allowedSkills': [
        'acrobatics',
        'animalHandling',
        'athletics',
        'history',
        'insight',
        'intimidation',
        'perception',
        'survival'
      ],
    },
    subclasses: [
      Subclass(
        id: const EntityId(slug: 'champion', ruleset: RulesetVersion.v2024),
        name: 'Champion',
        classSlug: 'fighter',
        featuresMarkdown:
            '**Improved Critical.** Your weapon attacks score a critical hit on a roll of 19 or 20.\n\n'
            '**Remarkable Athlete.** Bonus to non-proficient STR, DEX, and CON checks; increased jump distance.',
      ),
    ],
  );

  static final CharacterClass monk = CharacterClass(
    id: const EntityId(slug: 'monk', ruleset: RulesetVersion.v2024),
    name: 'Monk',
    hitDie: 'd8',
    primaryAbility: 'Dexterity and Wisdom',
    savingThrows: const ['Strength', 'Dexterity'],
    armorProficiencies: const [],
    weaponProficiencies: const ['Simple Weapons', 'Shortswords'],
    featuresMarkdown:
        '**Unarmored Defense.** When not wearing armor or wielding a shield, AC = 10 + DEX mod + WIS mod.\n\n'
        '**Martial Arts.** Use DEX for monk weapons and unarmed strikes; unarmed die scales from 1d6 to 1d12; bonus unarmed attack.\n\n'
        '**Ki / Focus Points.** Flurry of Blows, Patient Defense, Step of the Wind, Stunning Strike.\n\n'
        '**Deflect Attacks.** Reaction to reduce damage from ranged/melee attacks and deflect them back.',
    customProperties: const {
      'skillChoiceCount': 2,
      'allowedSkills': [
        'acrobatics',
        'athletics',
        'history',
        'insight',
        'religion',
        'stealth'
      ],
    },
    subclasses: [
      Subclass(
        id: const EntityId(slug: 'warrior-of-the-open-hand', ruleset: RulesetVersion.v2024),
        name: 'Warrior of the Open Hand',
        classSlug: 'monk',
        featuresMarkdown:
            '**Open Hand Technique.** Flurry of Blows can knock targets prone, push them 15 feet, or remove their reactions.',
      ),
    ],
  );

  static final CharacterClass paladin = CharacterClass(
    id: const EntityId(slug: 'paladin', ruleset: RulesetVersion.v2024),
    name: 'Paladin',
    hitDie: 'd10',
    primaryAbility: 'Strength and Charisma',
    savingThrows: const ['Wisdom', 'Charisma'],
    armorProficiencies: const ['All Armor', 'Shields'],
    weaponProficiencies: const ['Simple Weapons', 'Martial Weapons'],
    spellcastingAbility: 'Charisma',
    featuresMarkdown:
        '**Divine Sense.** Detect celestials, fiends, and undead.\n\n'
        '**Lay on Hands.** Pool of healing points equal to 5 × Paladin Level.\n\n'
        '**Divine Smite.** Channel holy wrath to deal extra radiant damage on melee hits.\n\n'
        '**Aura of Protection.** Add Charisma bonus to all saving throws for you and nearby allies.\n\n'
        '**Extra Attack.** Attack twice per Attack action.',
    customProperties: const {
      'skillChoiceCount': 2,
      'allowedSkills': [
        'athletics',
        'insight',
        'intimidation',
        'medicine',
        'persuasion',
        'religion'
      ],
    },
    subclasses: [
      Subclass(
        id: const EntityId(slug: 'oath-of-devotion', ruleset: RulesetVersion.v2024),
        name: 'Oath of Devotion',
        classSlug: 'paladin',
        featuresMarkdown:
            '**Sacred Weapon.** Add CHA modifier to weapon attack rolls and emit bright light.\n\n'
            '**Aura of Devotion.** Allies within 10 feet cannot be Charmed.',
      ),
    ],
  );

  static final CharacterClass ranger = CharacterClass(
    id: const EntityId(slug: 'ranger', ruleset: RulesetVersion.v2024),
    name: 'Ranger',
    hitDie: 'd10',
    primaryAbility: 'Dexterity and Wisdom',
    savingThrows: const ['Strength', 'Dexterity'],
    armorProficiencies: const ['Light Armor', 'Medium Armor', 'Shields'],
    weaponProficiencies: const ['Simple Weapons', 'Martial Weapons'],
    spellcastingAbility: 'Wisdom',
    featuresMarkdown:
        '**Deft Explorer / Natural Explorer.** Expertise in one skill, climbing and swimming speeds.\n\n'
        '**Favored Enemy / Hunter\'s Mark.** Cast Hunter\'s Mark without expending spell slots and track targets with Advantage.\n\n'
        '**Spellcasting.** Half-caster with primal nature spells.\n\n'
        '**Extra Attack.** Attack twice per Attack action.',
    customProperties: const {
      'skillChoiceCount': 3,
      'allowedSkills': [
        'animalHandling',
        'athletics',
        'insight',
        'investigation',
        'nature',
        'perception',
        'stealth',
        'survival'
      ],
    },
    subclasses: [
      Subclass(
        id: const EntityId(slug: 'hunter', ruleset: RulesetVersion.v2024),
        name: 'Hunter',
        classSlug: 'ranger',
        featuresMarkdown:
            '**Hunter\'s Prey.** Choose Colossus Slayer (+1d8 damage on injured foes), Giant Killer, or Horde Breaker.',
      ),
    ],
  );

  static final CharacterClass rogue = CharacterClass(
    id: const EntityId(slug: 'rogue', ruleset: RulesetVersion.v2024),
    name: 'Rogue',
    hitDie: 'd8',
    primaryAbility: 'Dexterity',
    savingThrows: const ['Dexterity', 'Intelligence'],
    armorProficiencies: const ['Light Armor'],
    weaponProficiencies: const [
      'Simple Weapons',
      'Hand Crossbows',
      'Longswords',
      'Rapiers',
      'Shortswords'
    ],
    featuresMarkdown:
        '**Sneak Attack.** Deal extra damage (+1d6 to +10d6) once per turn when attacking with Advantage or an ally is within 5 feet.\n\n'
        '**Thieves\' Cant.** Secret dialect and symbols of the underworld.\n\n'
        '**Cunning Action.** Bonus Action to Dash, Disengage, or Hide.\n\n'
        '**Uncanny Dodge.** Reaction to halve incoming attack damage.\n\n'
        '**Evasion.** Take no damage on successful DEX saves against area effects, and half damage on failure.',
    customProperties: const {
      'skillChoiceCount': 4,
      'allowedSkills': [
        'acrobatics',
        'athletics',
        'deception',
        'insight',
        'intimidation',
        'investigation',
        'perception',
        'performance',
        'persuasion',
        'sleightOfHand',
        'stealth'
      ],
    },
    subclasses: [
      Subclass(
        id: const EntityId(slug: 'thief', ruleset: RulesetVersion.v2024),
        name: 'Thief',
        classSlug: 'rogue',
        featuresMarkdown:
            '**Fast Hands.** Use Cunning Action to pick locks, disarm traps, or Use an Object.\n\n'
            '**Second-Story Work.** Climb without movement penalties and jump further.',
      ),
    ],
  );

  static final CharacterClass sorcerer = CharacterClass(
    id: const EntityId(slug: 'sorcerer', ruleset: RulesetVersion.v2024),
    name: 'Sorcerer',
    hitDie: 'd6',
    primaryAbility: 'Charisma',
    savingThrows: const ['Constitution', 'Charisma'],
    armorProficiencies: const [],
    weaponProficiencies: const [
      'Daggers',
      'Darts',
      'Slings',
      'Quarterstaffs',
      'Light Crossbows'
    ],
    spellcastingAbility: 'Charisma',
    featuresMarkdown:
        '**Innate Sorcery.** Innate magic flares to grant Advantage on spell attacks and increase spell save DC by 1.\n\n'
        '**Font of Magic.** Sorcery Points pool for creating spell slots or fueling Metamagic.\n\n'
        '**Metamagic.** Twinned Spell, Quickened Spell, Subtle Spell, Heightened Spell, Empowered Spell, Distant Spell.',
    customProperties: const {
      'skillChoiceCount': 2,
      'allowedSkills': [
        'arcana',
        'deception',
        'insight',
        'intimidation',
        'persuasion',
        'religion'
      ],
    },
    subclasses: [
      Subclass(
        id: const EntityId(slug: 'draconic-sorcery', ruleset: RulesetVersion.v2024),
        name: 'Draconic Sorcery',
        classSlug: 'sorcerer',
        featuresMarkdown:
            '**Draconic Resilience.** Base AC 13 + DEX mod, and +1 Max HP per Sorcerer level.\n\n'
            '**Elemental Affinity.** Add CHA modifier to damage matching draconic ancestry.',
      ),
    ],
  );

  static final CharacterClass warlock = CharacterClass(
    id: const EntityId(slug: 'warlock', ruleset: RulesetVersion.v2024),
    name: 'Warlock',
    hitDie: 'd8',
    primaryAbility: 'Charisma',
    savingThrows: const ['Wisdom', 'Charisma'],
    armorProficiencies: const ['Light Armor'],
    weaponProficiencies: const ['Simple Weapons'],
    spellcastingAbility: 'Charisma',
    featuresMarkdown:
        '**Pact Magic.** Recharges all max-level spell slots on a Short Rest.\n\n'
        '**Eldritch Invocations.** Agonizing Blast, Repelling Blast, Armor of Shadows, Devil\'s Sight, Mask of Many Faces, etc.\n\n'
        '**Pact Boon.** Pact of the Blade, Pact of the Tome, or Pact of the Chain.\n\n'
        '**Mystic Arcanum.** Cast 6th through 9th level spells once per long rest.',
    customProperties: const {
      'skillChoiceCount': 2,
      'allowedSkills': [
        'arcana',
        'deception',
        'history',
        'intimidation',
        'investigation',
        'nature',
        'religion'
      ],
    },
    subclasses: [
      Subclass(
        id: const EntityId(slug: 'fiend-patron', ruleset: RulesetVersion.v2024),
        name: 'The Fiend',
        classSlug: 'warlock',
        featuresMarkdown:
            '**Dark One\'s Blessing.** Gain temporary HP equal to CHA mod + Warlock Level upon reducing a hostile creature to 0 HP.\n\n'
            '**Dark One\'s Own Luck.** Add 1d10 to an ability check or saving throw.',
      ),
    ],
  );

  static final CharacterClass wizard = CharacterClass(
    id: const EntityId(slug: 'wizard', ruleset: RulesetVersion.v2024),
    name: 'Wizard',
    hitDie: 'd6',
    primaryAbility: 'Intelligence',
    savingThrows: const ['Intelligence', 'Wisdom'],
    armorProficiencies: const [],
    weaponProficiencies: const [
      'Daggers',
      'Darts',
      'Slings',
      'Quarterstaffs',
      'Light Crossbows'
    ],
    spellcastingAbility: 'Intelligence',
    featuresMarkdown:
        '**Spellbook.** Copy and master spells found in ancient scrolls and arcane tomes.\n\n'
        '**Ritual Casting.** Cast any ritual spell from your spellbook without preparing it.\n\n'
        '**Arcane Recovery.** Regain expended spell slots equal to half Wizard level on a Short Rest.\n\n'
        '**Spell Mastery.** Cast selected 1st and 2nd level spells at will.',
    customProperties: const {
      'skillChoiceCount': 2,
      'allowedSkills': [
        'arcana',
        'history',
        'insight',
        'investigation',
        'medicine',
        'religion'
      ],
    },
    subclasses: [
      Subclass(
        id: const EntityId(slug: 'school-of-evocation', ruleset: RulesetVersion.v2024),
        name: 'School of Evocation',
        classSlug: 'wizard',
        featuresMarkdown:
            '**Sculpt Spells.** Protect allies from taking damage or failing saving throws in your area of effect evocation spells.\n\n'
            '**Potent Cantrip.** Foes take half damage even on successful saves against your cantrips.\n\n'
            '**Overchannel.** Maximize damage dice for 1st-5th level spells.',
      ),
    ],
  );

  /// Base Core 12 SRD Classes
  static final List<CharacterClass> _baseClasses = [
    barbarian,
    bard,
    cleric,
    druid,
    fighter,
    monk,
    paladin,
    ranger,
    rogue,
    sorcerer,
    warlock,
    wizard,
  ];

  static List<CharacterClass> _customClasses = [];

  /// Dynamic list of all available classes (Base SRD + Custom Homebrew)
  static List<CharacterClass> get allClasses => [..._baseClasses, ..._customClasses];

  /// Sets the list of custom/homebrew classes
  static void setCustomClasses(List<CharacterClass> custom) {
    _customClasses = List<CharacterClass>.from(custom);
  }

  /// Adds or replaces a custom class in the library
  static void addCustomClass(CharacterClass cls) {
    _customClasses.removeWhere((c) => c.id.slug == cls.id.slug);
    _customClasses.add(cls);
  }

  /// Removes a custom class by slug
  static void removeCustomClass(String slug) {
    _customClasses.removeWhere((c) => c.id.slug == slug);
  }

  static CharacterClass? findBySlug(String slug) {
    final clean = slug.toLowerCase().trim();
    return allClasses.where((c) => c.id.slug == clean || c.name.toLowerCase() == clean).firstOrNull;
  }
}
