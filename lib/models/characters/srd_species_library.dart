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
      'abilityChoiceBonus': 1,
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
      const Subrace(
        id: EntityId(slug: 'high-elf', ruleset: RulesetVersion.v2024),
        name: 'High Elf',
        raceSlug: 'elf',
        abilityScoreSummary: '+1 INT',
        fixedAbilityBonuses: {'intelligence': 1},
        traitsMarkdown: '**Cantrip.** You know one cantrip of your choice from the Wizard spell list.\n\n**Elf Weapon Training.** Proficiency with longsword, shortsword, shortbow, and longbow.\n\n**Extra Language.** Speak, read, and write one extra language of your choice.',
      ),
      const Subrace(
        id: EntityId(slug: 'wood-elf', ruleset: RulesetVersion.v2024),
        name: 'Wood Elf',
        raceSlug: 'elf',
        abilityScoreSummary: '+1 WIS',
        fixedAbilityBonuses: {'wisdom': 1},
        speed: '35 ft.',
        traitsMarkdown: '**Fleet of Foot.** Your base walking speed increases to 35 feet.\n\n**Elf Weapon Training.** Proficiency with longsword, shortsword, shortbow, and longbow.\n\n**Mask of the Wild.** You can attempt to hide even when lightly obscured by foliage, heavy rain, or mist.',
      ),
      const Subrace(
        id: EntityId(slug: 'drow', ruleset: RulesetVersion.v2024),
        name: 'Drow',
        raceSlug: 'elf',
        abilityScoreSummary: '+1 CHA',
        fixedAbilityBonuses: {'charisma': 1},
        darkvision: 120,
        traitsMarkdown: '**Superior Darkvision.** Darkvision out to 120 feet.\n\n**Sunlight Sensitivity.** Disadvantage on attack rolls and Wisdom (Perception) checks relying on sight in direct sunlight.\n\n**Drow Magic.** Dancing Lights cantrip, Faerie Fire (level 3), Darkness (level 5).\n\n**Drow Weapon Training.** Proficiency with rapiers, shortswords, and hand crossbows.',
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
      const Subrace(
        id: EntityId(slug: 'hill-dwarf', ruleset: RulesetVersion.v2024),
        name: 'Hill Dwarf',
        raceSlug: 'dwarf',
        abilityScoreSummary: '+1 WIS',
        fixedAbilityBonuses: {'wisdom': 1},
        traitsMarkdown: '**Dwarven Toughness.** Your hit point maximum increases by 1, and increases by 1 every time you gain a level.',
      ),
      const Subrace(
        id: EntityId(slug: 'mountain-dwarf', ruleset: RulesetVersion.v2024),
        name: 'Mountain Dwarf',
        raceSlug: 'dwarf',
        abilityScoreSummary: '+2 STR',
        fixedAbilityBonuses: {'strength': 2},
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
      const Subrace(
        id: EntityId(slug: 'lightfoot-halfling', ruleset: RulesetVersion.v2024),
        name: 'Lightfoot Halfling',
        raceSlug: 'halfling',
        abilityScoreSummary: '+1 CHA',
        fixedAbilityBonuses: {'charisma': 1},
        traitsMarkdown: '**Naturally Stealthy.** You can attempt to hide even when obscured only by a larger creature.',
      ),
      const Subrace(
        id: EntityId(slug: 'stout-halfling', ruleset: RulesetVersion.v2024),
        name: 'Stout Halfling',
        raceSlug: 'halfling',
        abilityScoreSummary: '+1 CON',
        fixedAbilityBonuses: {'constitution': 1},
        traitsMarkdown: '**Stout Resilience.** You have advantage on saving throws against poison, and you have resistance against poison damage.',
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
    subraces: [
      const Subrace(
        id: EntityId(slug: 'forest-gnome', ruleset: RulesetVersion.v2024),
        name: 'Forest Gnome',
        raceSlug: 'gnome',
        abilityScoreSummary: '+1 DEX',
        fixedAbilityBonuses: {'dexterity': 1},
        traitsMarkdown: '**Natural Illusionist.** You know the Minor Illusion cantrip. Intelligence is your spellcasting ability for it.\n\n**Speak with Small Beasts.** Through sounds and gestures, you can communicate simple ideas with Small or smaller beasts.',
      ),
      const Subrace(
        id: EntityId(slug: 'rock-gnome', ruleset: RulesetVersion.v2024),
        name: 'Rock Gnome',
        raceSlug: 'gnome',
        abilityScoreSummary: '+1 CON',
        fixedAbilityBonuses: {'constitution': 1},
        traitsMarkdown: '**Artificer\'s Lore.** Double proficiency on Intelligence (History) checks related to magic items, alchemical objects, or technological devices.\n\n**Tinker.** Proficiency with tinker\'s tools to construct clockwork toys, fire starters, or music boxes.',
      ),
    ],
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
      'abilityChoiceCount': 2,
      'abilityChoiceBonus': 1,
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

  /// Base Core SRD Species unpolluted by custom species
  static List<Race> get baseSpecies => _baseSpecies;

  static List<Race> _customSpecies = [];
  static List<Subrace> _customSubraces = [];

  /// Standalone custom/homebrew subraces
  static List<Subrace> get customSubraces => List.unmodifiable(_customSubraces);

  /// Dynamic list of all available species (Base SRD + Custom Homebrew) with custom subraces attached
  static List<Race> get allSpecies {
    return [..._baseSpecies, ..._customSpecies].map((r) {
      final cleanRaceSlug = r.id.slug.toLowerCase().trim();
      final cleanRaceName = r.name.toLowerCase().trim();

      final matchingCustomSubraces = _customSubraces.where((s) {
        final subRaceSlug = s.raceSlug.toLowerCase().trim();
        return subRaceSlug == cleanRaceSlug ||
            subRaceSlug == cleanRaceName ||
            subRaceSlug.replaceAll('-', ' ') == cleanRaceName ||
            subRaceSlug.replaceAll(' ', '-') == cleanRaceSlug;
      }).toList();

      if (matchingCustomSubraces.isEmpty) return r;

      final existingSlugs = r.subraces.map((s) => s.id.slug.toLowerCase().trim()).toSet();
      final newSubraces = matchingCustomSubraces.where((s) => !existingSlugs.contains(s.id.slug.toLowerCase().trim())).toList();

      if (newSubraces.isEmpty) return r;
      return r.copyWith(subraces: [...r.subraces, ...newSubraces]);
    }).toList();
  }

  /// Sets the list of custom/homebrew species
  static void setCustomSpecies(List<Race> custom) {
    _customSpecies = List<Race>.from(custom);
  }

  /// Sets the list of standalone custom/homebrew subraces
  static void setCustomSubraces(List<Subrace> custom) {
    _customSubraces = List<Subrace>.from(custom);
  }

  /// Adds or replaces a custom species in the library
  static void addCustomSpecies(Race race) {
    _customSpecies.removeWhere((r) => r.id.slug == race.id.slug);
    _customSpecies.add(race);
  }

  /// Adds or replaces a custom subrace in the library
  static void addCustomSubrace(Subrace subrace) {
    _customSubraces.removeWhere((s) => s.id.slug == subrace.id.slug);
    _customSubraces.add(subrace);
  }

  /// Removes a custom species by slug
  static void removeCustomSpecies(String slug) {
    _customSpecies.removeWhere((r) => r.id.slug == slug);
  }

  /// Removes a custom subrace by slug
  static void removeCustomSubrace(String slug) {
    _customSubraces.removeWhere((s) => s.id.slug == slug);
  }

  static List<Race> getSpeciesForRuleset(RulesetVersion ruleset) {
    if (ruleset == RulesetVersion.v2024) {
      // In 2024, standard Human is used (Resourceful, Skillful, Versatile)
      return allSpecies.where((r) => r.id.slug != 'human-variant' && r.id.slug != 'custom-lineage').toList();
    }
    return allSpecies;
  }

  static Race? findBySlug(String slug) {
    final clean = slug.toLowerCase().trim();
    return allSpecies.where((r) => r.id.slug == clean || r.name.toLowerCase() == clean).firstOrNull;
  }

  static Subrace? findSubraceBySlug(String slug) {
    final clean = slug.toLowerCase().trim();
    for (final r in allSpecies) {
      for (final s in r.subraces) {
        if (s.id.slug.toLowerCase().trim() == clean || s.name.toLowerCase().trim() == clean) {
          return s;
        }
      }
    }
    return _customSubraces.where((s) => s.id.slug.toLowerCase().trim() == clean || s.name.toLowerCase().trim() == clean).firstOrNull;
  }
}
