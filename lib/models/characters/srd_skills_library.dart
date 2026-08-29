import 'package:flutter/foundation.dart';
import '../domain/character_models.dart';

/// Full metadata descriptor for a 5e Skill
@immutable
class SkillDefinition {
  final SkillType skill;
  final String name;
  final AbilityType defaultAbility;
  final String description;
  final String examples;
  final String actionType2024; // e.g. "Search", "Study", "Influence", "Free/Movement"
  final String keyChanges2024;

  const SkillDefinition({
    required this.skill,
    required this.name,
    required this.defaultAbility,
    required this.description,
    required this.examples,
    this.actionType2024 = 'General',
    this.keyChanges2024 = 'Standard D20 check against Target DC.',
  });
}

/// Comprehensive SRD Skills Library with complete descriptions and mechanical rules.
@immutable
class SrdSkillsLibrary {
  static const List<SkillDefinition> allSkills = [
    SkillDefinition(
      skill: SkillType.acrobatics,
      name: 'Acrobatics',
      defaultAbility: AbilityType.dexterity,
      description:
          'Covers your attempt to stay on your feet in a tricky situation, such as balancing on tightropes, navigating ice sheets, or doing dives and backflips.',
      examples:
          'Running across a narrow ledge, maintaining balance on a rocking ship deck, escaping grapples/restraints, landing gracefully after a fall.',
      actionType2024: 'Movement / Reaction',
      keyChanges2024:
          'Contesting grapples is now resolved against DC rather than dynamic opposed rolls in 2024 rules.',
    ),
    SkillDefinition(
      skill: SkillType.animalHandling,
      name: 'Animal Handling',
      defaultAbility: AbilityType.wisdom,
      description:
          'Measures your intuition to calm down a domesticated animal, keep a mount from getting spooked, or intuit an animal\'s intentions.',
      examples:
          'Calming a frightened horse, directing a draft animal through gunfire, intuiting a beast\'s mood, coaxing a wild animal.',
      actionType2024: 'Influence',
      keyChanges2024:
          'Classified under the standard Influence action for beasts and companion creatures.',
    ),
    SkillDefinition(
      skill: SkillType.arcana,
      name: 'Arcana',
      defaultAbility: AbilityType.intelligence,
      description:
          'Measures your lore knowledge about spells, magic items, eldritch symbols, magical traditions, the planes of existence, and planar inhabitants.',
      examples:
          'Identifying the school of a magical rune, recalling lore about planar gates, recognizing magical anomalies or constructs.',
      actionType2024: 'Study',
      keyChanges2024:
          'Formalized as a Study Action (DC 10-25) to identify active spell effects and planar phenomena.',
    ),
    SkillDefinition(
      skill: SkillType.athletics,
      name: 'Athletics',
      defaultAbility: AbilityType.strength,
      description:
          'Covers difficult situations you encounter while climbing, jumping, swimming, or forcing open stuck doors and wrestling adversaries.',
      examples:
          'Climbing a sheer cliff, leaping across a chasm, swimming against a raging rapid, breaking through barred doors.',
      actionType2024: 'Movement / Action',
      keyChanges2024:
          'Shove and Grapple checks now set an Escape DC based on 8 + STR mod + Prof Bonus.',
    ),
    SkillDefinition(
      skill: SkillType.deception,
      name: 'Deception',
      defaultAbility: AbilityType.charisma,
      description:
          'Determines whether you can convincingly hide the truth, either verbally or through your actions, disguises, misdirection, or fast talk.',
      examples:
          'Fast-talking a city guard, conning a merchant, forging documents convincingly, passing unnoticed in disguise.',
      actionType2024: 'Influence',
      keyChanges2024:
          'Used under the Influence action against NPC attitudes (Hostile, Indifferent, Friendly).',
    ),
    SkillDefinition(
      skill: SkillType.history,
      name: 'History',
      defaultAbility: AbilityType.intelligence,
      description:
          'Measures your ability to recall lore about historical events, legendary people, ancient kingdoms, past disputes, wars, and lost civilizations.',
      examples:
          'Recognizing an ancient family heraldry, recalling the builder of a sunken fortress, knowing the terms of an old treaty.',
      actionType2024: 'Study',
      keyChanges2024:
          'Formal Study Action. Provides historical context and unlocks hidden dungeon knowledge.',
    ),
    SkillDefinition(
      skill: SkillType.insight,
      name: 'Insight',
      defaultAbility: AbilityType.wisdom,
      description:
          'Decides whether you can determine the true intentions of a creature, such as searching out a lie or predicting someone\'s next move through body language.',
      examples:
          'Detecting if an NPC is concealing vital facts, gauging a merchant\'s baseline honesty, reading nervous eye movements.',
      actionType2024: 'Influence / Search',
      keyChanges2024:
          'Passive Insight (10 + WIS mod + Prof) sets the DC for incoming deceit and hidden motives.',
    ),
    SkillDefinition(
      skill: SkillType.intimidation,
      name: 'Intimidation',
      defaultAbility: AbilityType.charisma,
      description:
          'Used when you attempt to influence someone through overt threats, hostile actions, terrifying presence, or brandished steel.',
      examples:
          'Extracting information from a captured bandit, staring down a barroom brawler, convincing a coward to flee.',
      actionType2024: 'Influence',
      keyChanges2024:
          'Can cause target to become Frightened or comply with immediate demands based on DC.',
    ),
    SkillDefinition(
      skill: SkillType.investigation,
      name: 'Investigation',
      defaultAbility: AbilityType.intelligence,
      description:
          'Used when you look around for clues, make deductions based on evidence, search hidden compartments, or unravel ciphers.',
      examples:
          'Finding hidden trap triggers, deducing the murder weapon from blood spatter, opening secret doors, reading cryptic clues.',
      actionType2024: 'Search',
      keyChanges2024:
          'Formal Search Action. Standard check to detect concealed objects, false walls, and structural traps.',
    ),
    SkillDefinition(
      skill: SkillType.medicine,
      name: 'Medicine',
      defaultAbility: AbilityType.wisdom,
      description:
          'Lets you stabilize a dying companion, diagnose illness, identify cause of death, or synthesize herbal remedies.',
      examples:
          'Stabilizing an ally at 0 HP (DC 10), diagnosing toxic venom, treating a battlefield wound.',
      actionType2024: 'Action',
      keyChanges2024:
          'DC 10 to stabilize a dying creature without spending a Healer\'s Kit use.',
    ),
    SkillDefinition(
      skill: SkillType.nature,
      name: 'Nature',
      defaultAbility: AbilityType.intelligence,
      description:
          'Measures your knowledge about terrain, flora and fauna, weather patterns, ecosystems, and elemental cycles.',
      examples:
          'Identifying edible berries vs poisonous mushrooms, recognizing a beast\'s hunting territory, predicting incoming blizzards.',
      actionType2024: 'Study',
      keyChanges2024:
          'Study Action used to recall weaknesses, resistances, and habitat information for natural monsters and beasts.',
    ),
    SkillDefinition(
      skill: SkillType.perception,
      name: 'Perception',
      defaultAbility: AbilityType.wisdom,
      description:
          'Lets you see, hear, or otherwise detect the presence of something. Measures your general awareness of your surroundings and the keenness of your senses.',
      examples:
          'Eavesdropping on a conversation behind a closed door, spotting hidden ambushes, noticing footsteps in the corridor.',
      actionType2024: 'Search',
      keyChanges2024:
          'Search Action vs creature Stealth checks. Passive Perception remains the universal baseline awareness.',
    ),
    SkillDefinition(
      skill: SkillType.performance,
      name: 'Performance',
      defaultAbility: AbilityType.charisma,
      description:
          'Delights an audience with music, dance, acting, storytelling, or other forms of entertainment.',
      examples:
          'Playing a lute for tavern patrons, acting in a theatrical play, captivating a royal court with an epic tale.',
      actionType2024: 'Influence',
      keyChanges2024:
          'Integrates directly with the Musician Origin Feat and Bardic Performance features.',
    ),
    SkillDefinition(
      skill: SkillType.persuasion,
      name: 'Persuasion',
      defaultAbility: AbilityType.charisma,
      description:
          'Used when attempting to influence someone or an entire group with tact, social graces, good nature, or diplomacy.',
      examples:
          'Negotiating a diplomatic truce, bargaining for better quest rewards, convincing an NPC of your noble intentions.',
      actionType2024: 'Influence',
      keyChanges2024:
          'Standard Influence Action to shift NPC attitudes from Hostile -> Indifferent -> Friendly.',
    ),
    SkillDefinition(
      skill: SkillType.religion,
      name: 'Religion',
      defaultAbility: AbilityType.intelligence,
      description:
          'Measures your lore regarding deities, rites and prayers, religious hierarchies, holy symbols, and the practices of secret cults.',
      examples:
          'Recognizing an unholy deity altar, knowing the burial rites of an ancient priesthood, discerning divine omens.',
      actionType2024: 'Study',
      keyChanges2024:
          'Study Action to decipher fiendish, celestial, and undead lore, curses, and sacred rituals.',
    ),
    SkillDefinition(
      skill: SkillType.sleightOfHand,
      name: 'Sleight of Hand',
      defaultAbility: AbilityType.dexterity,
      description:
          'Whenever you attempt an act of legerdemain or manual trickery, such as planting something on someone else or concealing an object.',
      examples:
          'Picking a nobleman\'s pocket, slipping a poison into a drink unnoticed, palming a coin, performing street magic.',
      actionType2024: 'Action',
      keyChanges2024:
          'Can be used alongside Thieves\' Tools proficiency for picking locks and disarming complex clockwork traps.',
    ),
    SkillDefinition(
      skill: SkillType.stealth,
      name: 'Stealth',
      defaultAbility: AbilityType.dexterity,
      description:
          'Make a Dexterity (Stealth) check when you attempt to conceal yourself from enemies, slink past guards, slip away without being noticed, or sneak up on someone.',
      examples:
          'Hiding in shadows behind cover, walking silently across dry leaves, slipping past sentries undetected.',
      actionType2024: 'Hide',
      keyChanges2024:
          'Hide Action grants the Invisible condition until you make noise, attack, or are spotted (DC 15 minimum in 2024).',
    ),
    SkillDefinition(
      skill: SkillType.survival,
      name: 'Survival',
      defaultAbility: AbilityType.wisdom,
      description:
          'Follow tracks, hunt wild game, guide your group through frozen wastelands, identify signs of owlbears, or avoid quicksand and other natural hazards.',
      examples:
          'Tracking wounded prey across muddy terrain, finding freshwater sources in the desert, foraging for food during travel.',
      actionType2024: 'Search / Travel',
      keyChanges2024:
          'Used for navigation checks and foraging without losing travel pace.',
    ),
  ];

  static SkillDefinition getDefinition(SkillType skill) {
    return allSkills.firstWhere((s) => s.skill == skill);
  }

  static List<SkillDefinition> getByAbility(AbilityType ability) {
    return allSkills.where((s) => s.defaultAbility == ability).toList();
  }
}
