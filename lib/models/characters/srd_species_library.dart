import 'package:flutter/foundation.dart';
import '../domain/core_types.dart';
import '../domain/homebrew_extended_entities.dart';

/// Comprehensive SRD Species & Races Library.
@immutable
class SrdSpeciesLibrary {
  static final Race human = Race(
    id: const EntityId(slug: 'human', ruleset: RulesetVersion.v2024),
    name: 'Human',
    size: 'Medium',
    speed: '30 ft.',
    abilityScoreSummary: '+1 to All (2014) or +2/+1 from Background (2024)',
    traitsMarkdown:
        '**Resourceful.** You gain Heroic Inspiration whenever you finish a Long Rest.\n\n'
        '**Skillful.** You gain proficiency in one skill of your choice.\n\n'
        '**Versatile.** You gain an Origin Feat of your choice.',
    customProperties: const {
      'hasDarkvision': false,
      'bonusOriginFeat': true,
      'bonusSkillCount': 1,
      'abilityBonuses2014': {
        'strength': 1,
        'dexterity': 1,
        'constitution': 1,
        'intelligence': 1,
        'wisdom': 1,
        'charisma': 1,
      },
    },
  );

  static final Race humanVariant = Race(
    id: const EntityId(slug: 'human-variant', ruleset: RulesetVersion.v2014),
    name: 'Human (Variant)',
    size: 'Medium',
    speed: '30 ft.',
    abilityScoreSummary: '+1 to Two Different Scores, 1 Skill, 1 Feat (2014 Optional)',
    traitsMarkdown:
        '**Ability Score Increase.** Two different ability scores of your choice increase by 1.\n\n'
        '**Skills.** You gain proficiency in one skill of your choice.\n\n'
        '**Feat.** You gain one Feat of your choice from the Feat library.',
    customProperties: const {
      'hasDarkvision': false,
      'isVariantHuman': true,
      'bonusSkillCount': 1,
      'bonusFeatCount': 1,
      'abilityChoiceCount': 2,
    },
  );

  static final Race elf = Race(
    id: const EntityId(slug: 'elf', ruleset: RulesetVersion.v2024),
    name: 'Elf',
    size: 'Medium',
    speed: '30 ft.',
    abilityScoreSummary: '+2 DEX (2014) or Background (2024)',
    traitsMarkdown:
        '**Darkvision.** You can see in dim light within 60 feet as if it were bright light, and in darkness as if it were dim light.\n\n'
        '**Elven Lineage.** Choose High Elf (bonus wizard cantrip), Wood Elf (35 ft speed), or Drow (120 ft darkvision).\n\n'
        '**Fey Ancestry.** You have Advantage on saving throws you make to avoid or end the Charmed condition on yourself.\n\n'
        '**Keen Senses.** You have proficiency in the Perception skill.\n\n'
        '**Trance.** You don’t need to sleep. Magic can’t put you to sleep. Finish a Long Rest in 4 hours.',
    customProperties: const {
      'hasDarkvision': true,
      'darkvisionFeet': 60,
      'grantedSkill': 'perception',
      'abilityBonuses2014': {'dexterity': 2},
    },
    subraces: [
      Subrace(
        id: const EntityId(slug: 'high-elf', ruleset: RulesetVersion.v2024),
        name: 'High Elf',
        raceSlug: 'elf',
        traitsMarkdown: '**Cantrip.** You know one cantrip of your choice from the Wizard spell list.',
      ),
      Subrace(
        id: const EntityId(slug: 'wood-elf', ruleset: RulesetVersion.v2024),
        name: 'Wood Elf',
        raceSlug: 'elf',
        traitsMarkdown: '**Fleet of Foot.** Your base walking speed increases to 35 feet.',
      ),
    ],
  );

  static final Race dwarf = Race(
    id: const EntityId(slug: 'dwarf', ruleset: RulesetVersion.v2024),
    name: 'Dwarf',
    size: 'Medium',
    speed: '30 ft.',
    abilityScoreSummary: '+2 CON (2014) or Background (2024)',
    traitsMarkdown:
        '**Darkvision.** See in dim light within 60 feet (or 120 feet for 2024).\n\n'
        '**Dwarven Resilience.** Advantage on saving throws against Poison, and Resistance to poison damage.\n\n'
        '**Dwarven Toughness.** Your HP maximum increases by 1 for every level you have.\n\n'
        '**Stonecunning.** Tremorsense 60 ft on stone surfaces as a Bonus Action (2024) or History check double proficiency on stone (2014).',
    customProperties: const {
      'hasDarkvision': true,
      'darkvisionFeet': 60,
      'poisonResistance': true,
      'hpPerLevelBonus': 1,
      'abilityBonuses2014': {'constitution': 2},
    },
    subraces: [
      Subrace(
        id: const EntityId(slug: 'hill-dwarf', ruleset: RulesetVersion.v2024),
        name: 'Hill Dwarf',
        raceSlug: 'dwarf',
        traitsMarkdown: '**Dwarven Toughness.** +1 HP maximum per level.',
      ),
      Subrace(
        id: const EntityId(slug: 'mountain-dwarf', ruleset: RulesetVersion.v2024),
        name: 'Mountain Dwarf',
        raceSlug: 'dwarf',
        traitsMarkdown: '**Dwarven Armor Training.** Proficiency with light and medium armor.',
      ),
    ],
  );

  static final Race halfling = Race(
    id: const EntityId(slug: 'halfling', ruleset: RulesetVersion.v2024),
    name: 'Halfling',
    size: 'Small',
    speed: '30 ft.',
    abilityScoreSummary: '+2 DEX (2014) or Background (2024)',
    traitsMarkdown:
        '**Lucky.** When you roll a 1 on the d20 for an attack roll, ability check, or saving throw, you can reroll the die and must use the new roll.\n\n'
        '**Brave.** You have Advantage on saving throws you make to avoid or end the Frightened condition.\n\n'
        '**Halfling Nimbleness.** You can move through the space of any creature that is a size larger than yours.',
    customProperties: const {
      'hasDarkvision': false,
      'halflingLucky': true,
      'abilityBonuses2014': {'dexterity': 2},
    },
    subraces: [
      Subrace(
        id: const EntityId(slug: 'lightfoot-halfling', ruleset: RulesetVersion.v2024),
        name: 'Lightfoot Halfling',
        raceSlug: 'halfling',
        traitsMarkdown: '**Naturally Stealthy.** You can attempt to hide even when obscured only by a larger creature.',
      ),
    ],
  );

  static final Race dragonborn = Race(
    id: const EntityId(slug: 'dragonborn', ruleset: RulesetVersion.v2024),
    name: 'Dragonborn',
    size: 'Medium',
    speed: '30 ft.',
    abilityScoreSummary: '+2 STR, +1 CHA (2014) or Background (2024)',
    traitsMarkdown:
        '**Draconic Breath Weapon.** Exhale elemental energy in a 15-foot cone or 30-foot line dealing 1d10 (scaling to 4d10) elemental damage.\n\n'
        '**Damage Resistance.** Resistance to the damage type associated with your draconic ancestry (Fire, Cold, Lightning, Acid, or Poison).\n\n'
        '**Darkvision.** See in dim light within 60 feet.\n\n'
        '**Draconic Flight.** Temporarily sprout spectral wings at level 5 (2024 rules).',
    customProperties: const {
      'hasDarkvision': true,
      'darkvisionFeet': 60,
      'breathWeapon': true,
      'abilityBonuses2014': {'strength': 2, 'charisma': 1},
    },
  );

  static final Race gnome = Race(
    id: const EntityId(slug: 'gnome', ruleset: RulesetVersion.v2024),
    name: 'Gnome',
    size: 'Small',
    speed: '30 ft.',
    abilityScoreSummary: '+2 INT (2014) or Background (2024)',
    traitsMarkdown:
        '**Gnomish Cunning.** You have Advantage on Intelligence, Wisdom, and Charisma saving throws against magic.\n\n'
        '**Darkvision.** See in dim light within 60 feet.\n\n'
        '**Gnomish Lineage.** Choose Forest Gnome (Minor Illusion cantrip, speak with small beasts) or Rock Gnome (Tinker tools and clockwork gadgets).',
    customProperties: const {
      'hasDarkvision': true,
      'darkvisionFeet': 60,
      'gnomeCunning': true,
      'abilityBonuses2014': {'intelligence': 2},
    },
  );

  static final Race halfElf = Race(
    id: const EntityId(slug: 'half-elf', ruleset: RulesetVersion.v2014),
    name: 'Half-Elf',
    size: 'Medium',
    speed: '30 ft.',
    abilityScoreSummary: '+2 CHA, +1 to two other scores',
    traitsMarkdown:
        '**Darkvision.** See in dim light within 60 feet.\n\n'
        '**Fey Ancestry.** Advantage on saving throws against being Charmed; magic can\'t put you to sleep.\n\n'
        '**Skill Versatility.** Gain proficiency in two skills of your choice.',
    customProperties: const {
      'hasDarkvision': true,
      'darkvisionFeet': 60,
      'bonusSkillCount': 2,
      'abilityBonuses2014': {'charisma': 2},
    },
  );

  static final Race halfOrc = Race(
    id: const EntityId(slug: 'half-orc', ruleset: RulesetVersion.v2014),
    name: 'Half-Orc / Orc',
    size: 'Medium',
    speed: '30 ft.',
    abilityScoreSummary: '+2 STR, +1 CON',
    traitsMarkdown:
        '**Darkvision.** See in dim light within 60 feet (or 120 ft for Orc).\n\n'
        '**Relentless Endurance.** When reduced to 0 HP but not killed outright, drop to 1 HP instead once per Long Rest.\n\n'
        '**Savage Attacks.** When you score a critical hit with a melee weapon, roll one of the weapon’s damage dice one additional time.\n\n'
        '**Menacing.** Gain proficiency in the Intimidation skill.',
    customProperties: const {
      'hasDarkvision': true,
      'darkvisionFeet': 60,
      'relentlessEndurance': true,
      'grantedSkill': 'intimidation',
      'abilityBonuses2014': {'strength': 2, 'constitution': 1},
    },
  );

  static final Race tiefling = Race(
    id: const EntityId(slug: 'tiefling', ruleset: RulesetVersion.v2024),
    name: 'Tiefling',
    size: 'Medium',
    speed: '30 ft.',
    abilityScoreSummary: '+2 CHA, +1 INT (2014) or Background (2024)',
    traitsMarkdown:
        '**Darkvision.** See in dim light within 60 feet.\n\n'
        '**Hellfire / Fiendish Resistance.** Resistance to Fire damage (or Cold/Poison for Abyssal/Chthonic lineages).\n\n'
        '**Otherworldly Presence / Thaumaturgy.** You know the Thaumaturgy cantrip. At level 3 you can cast Hellish Rebuke, and at level 5 Darkness.',
    customProperties: const {
      'hasDarkvision': true,
      'darkvisionFeet': 60,
      'fireResistance': true,
      'abilityBonuses2014': {'charisma': 2, 'intelligence': 1},
    },
  );

  /// Base Core SRD Species / Races
  static final List<Race> _baseSpecies = [
    human,
    humanVariant,
    elf,
    dwarf,
    halfling,
    dragonborn,
    gnome,
    halfElf,
    halfOrc,
    tiefling,
  ];

  static List<Race> _customSpecies = [];

  /// Dynamic list of all available species (Base SRD + Custom Homebrew)
  static List<Race> get allSpecies => [..._baseSpecies, ..._customSpecies];

  /// Sets the list of custom/homebrew species
  static void setCustomSpecies(List<Race> custom) {
    _customSpecies = List<Race>.from(custom);
  }

  /// Adds or replaces a custom species in the library
  static void addCustomSpecies(Race race) {
    _customSpecies.removeWhere((r) => r.id.slug == race.id.slug);
    _customSpecies.add(race);
  }

  /// Removes a custom species by slug
  static void removeCustomSpecies(String slug) {
    _customSpecies.removeWhere((r) => r.id.slug == slug);
  }

  static List<Race> getSpeciesForRuleset(RulesetVersion ruleset) {
    if (ruleset == RulesetVersion.v2024) {
      // In 2024, standard Human is used (Resourceful, Skillful, Versatile)
      return allSpecies.where((r) => r.id.slug != 'human-variant').toList();
    }
    return allSpecies;
  }

  static Race? findBySlug(String slug) {
    final clean = slug.toLowerCase().trim();
    return allSpecies.where((r) => r.id.slug == clean || r.name.toLowerCase() == clean).firstOrNull;
  }
}
