import 'package:flutter/foundation.dart';
import '../domain/core_types.dart';
import '../domain/homebrew_extended_entities.dart';

/// Comprehensive SRD Backgrounds Library.
@immutable
class SrdBackgroundsLibrary {
  static const Background acolyte = Background(
    id: EntityId(slug: 'acolyte', ruleset: RulesetVersion.v2024),
    name: 'Acolyte',
    abilityScoreSummary: 'Intelligence, Wisdom, Charisma',
    originFeat: 'Magic Initiate (Cleric)',
    skillProficiencies: ['Insight', 'Religion'],
    toolProficiencies: ['Calligrapher\'s Supplies'],
    languages: ['Celestial'],
    descriptionMarkdown:
        'You devoted yourself to service in a temple, performing sacred rites and offering sacrifices at the altar of your deity.\n\n'
        '**Origin Feat:** Magic Initiate (Cleric) or Healer\n'
        '**Ability Scores:** +2 WIS / +1 CHA (or any combination)\n'
        '**Starting Equipment:** Holy Symbol, Prayer Book, 5 Sticks of Incense, Vestments, 15 GP.',
  );

  static const Background criminal = Background(
    id: EntityId(slug: 'criminal', ruleset: RulesetVersion.v2024),
    name: 'Criminal',
    abilityScoreSummary: 'Dexterity, Constitution, Intelligence',
    originFeat: 'Alert',
    skillProficiencies: ['Deception', 'Stealth'],
    toolProficiencies: ['Thieves\' Tools', 'Gaming Set (Dice)'],
    descriptionMarkdown:
        'You have a history of breaking the law and surviving in the criminal underworld through cunning, stealth, and contacts.\n\n'
        '**Origin Feat:** Alert\n'
        '**Ability Scores:** +2 DEX / +1 CON\n'
        '**Starting Equipment:** Crowbar, Dark Common Clothes with Hood, Thieves\' Tools, Pouch with 16 GP.',
  );

  static const Background entertainer = Background(
    id: EntityId(slug: 'entertainer', ruleset: RulesetVersion.v2024),
    name: 'Entertainer',
    abilityScoreSummary: 'Strength, Dexterity, Charisma',
    originFeat: 'Musician',
    skillProficiencies: ['Acrobatics', 'Performance'],
    toolProficiencies: ['Disguise Kit', 'Musical Instrument (Lute)'],
    descriptionMarkdown:
        'You thrive in front of an audience, knowing how to entrance, entertain, and inspire crowds of commoners and nobles alike.\n\n'
        '**Origin Feat:** Musician\n'
        '**Ability Scores:** +2 CHA / +1 DEX\n'
        '**Starting Equipment:** Musical Instrument, Costume Clothes, Mirror, Perfume, Pouch with 16 GP.',
  );

  static const Background folkHero = Background(
    id: EntityId(slug: 'folk-hero', ruleset: RulesetVersion.v2024),
    name: 'Folk Hero / Guide',
    abilityScoreSummary: 'Strength, Constitution, Wisdom',
    originFeat: 'Tough',
    skillProficiencies: ['Animal Handling', 'Survival'],
    toolProficiencies: ['Woodcarver\'s Tools', 'Vehicles (Land)'],
    descriptionMarkdown:
        'You come from humble origins, but destiny called you to stand against bullies, monsters, or oppressive local tyrants.\n\n'
        '**Origin Feat:** Tough\n'
        '**Ability Scores:** +2 CON / +1 WIS\n'
        '**Starting Equipment:** Artisan\'s Tools, Shovel, Iron Pot, Set of Common Clothes, Pouch with 10 GP.',
  );

  static const Background guildArtisan = Background(
    id: EntityId(slug: 'guild-artisan', ruleset: RulesetVersion.v2024),
    name: 'Guild Artisan / Merchant',
    abilityScoreSummary: 'Strength, Dexterity, Intelligence',
    originFeat: 'Crafter',
    skillProficiencies: ['Insight', 'Persuasion'],
    toolProficiencies: ['Smith\'s Tools / Artisan\'s Tools'],
    languages: ['Dwarvish'],
    descriptionMarkdown:
        'You are a member of an established guild of craftspeople, masters of trade, production, and commerce.\n\n'
        '**Origin Feat:** Crafter\n'
        '**Ability Scores:** +2 INT / +1 CHA\n'
        '**Starting Equipment:** Set of Artisan\'s Tools, Letter of Introduction, Traveler\'s Clothes, Pouch with 15 GP.',
  );

  static const Background noble = Background(
    id: EntityId(slug: 'noble', ruleset: RulesetVersion.v2024),
    name: 'Noble',
    abilityScoreSummary: 'Strength, Intelligence, Charisma',
    originFeat: 'Skilled',
    skillProficiencies: ['History', 'Persuasion'],
    toolProficiencies: ['Gaming Set (Dragonchess)'],
    languages: ['Draconic'],
    descriptionMarkdown:
        'You were born into wealth, power, and privilege, carrying an aristocratic title and ancestral coat of arms.\n\n'
        '**Origin Feat:** Skilled\n'
        '**Ability Scores:** +2 CHA / +1 INT\n'
        '**Starting Equipment:** Fine Clothes, Signet Ring, Scroll of Pedigree, Purse with 25 GP.',
  );

  static const Background sage = Background(
    id: EntityId(slug: 'sage', ruleset: RulesetVersion.v2024),
    name: 'Sage',
    abilityScoreSummary: 'Constitution, Intelligence, Wisdom',
    originFeat: 'Magic Initiate (Wizard)',
    skillProficiencies: ['Arcana', 'History'],
    toolProficiencies: ['Calligrapher\'s Supplies'],
    languages: ['Elvish', 'Draconic'],
    descriptionMarkdown:
        'You spent years secluded in libraries and arcane scriptoriums cataloging manuscripts and ancient histories.\n\n'
        '**Origin Feat:** Magic Initiate (Wizard)\n'
        '**Ability Scores:** +2 INT / +1 WIS\n'
        '**Starting Equipment:** Bottle of Black Ink, Quill, Small Knife, Letter from Colleague, Common Clothes, 10 GP.',
  );

  static const Background sailor = Background(
    id: EntityId(slug: 'sailor', ruleset: RulesetVersion.v2024),
    name: 'Sailor',
    abilityScoreSummary: 'Strength, Dexterity, Wisdom',
    originFeat: 'Tavern Brawler',
    skillProficiencies: ['Athletics', 'Perception'],
    toolProficiencies: ['Navigator\'s Tools', 'Vehicles (Water)'],
    descriptionMarkdown:
        'You sailed on seafaring vessels facing stormy gales, sea monsters, and coastal pirates.\n\n'
        '**Origin Feat:** Tavern Brawler\n'
        '**Ability Scores:** +2 DEX / +1 STR\n'
        '**Starting Equipment:** Belaying Pin (Club), 50 ft of Silk Rope, Lucky Charm, Common Clothes, 10 GP.',
  );

  static const Background soldier = Background(
    id: EntityId(slug: 'soldier', ruleset: RulesetVersion.v2024),
    name: 'Soldier',
    abilityScoreSummary: 'Strength, Dexterity, Constitution',
    originFeat: 'Savage Attacker',
    skillProficiencies: ['Athletics', 'Intimidation'],
    toolProficiencies: ['Gaming Set (Cards)', 'Vehicles (Land)'],
    descriptionMarkdown:
        'You trained in military tactics and discipline, serving on the front lines of defense in warfare.\n\n'
        '**Origin Feat:** Savage Attacker\n'
        '**Ability Scores:** +2 STR / +1 CON\n'
        '**Starting Equipment:** Insignia of Rank, Trophy taken from fallen foe, Bone Dice, Common Clothes, 10 GP.',
  );

  static const Background urchin = Background(
    id: EntityId(slug: 'urchin', ruleset: RulesetVersion.v2024),
    name: 'Urchin',
    abilityScoreSummary: 'Dexterity, Constitution, Wisdom',
    originFeat: 'Lucky',
    skillProficiencies: ['Sleight of Hand', 'Stealth'],
    toolProficiencies: ['Disguise Kit', 'Thieves\' Tools'],
    descriptionMarkdown:
        'You grew up alone on the streets, orphaned and poor, surviving through quick reflexes and sharp wits.\n\n'
        '**Origin Feat:** Lucky\n'
        '**Ability Scores:** +2 DEX / +1 WIS\n'
        '**Starting Equipment:** Small Knife, Map of Hometown, Pet Mouse, Token to Remember Parents, Common Clothes, 10 GP.',
  );

  /// Base Core SRD Backgrounds
  static final List<Background> _baseBackgrounds = [
    acolyte,
    criminal,
    entertainer,
    folkHero,
    guildArtisan,
    noble,
    sage,
    sailor,
    soldier,
    urchin,
  ];

  static List<Background> _customBackgrounds = [];

  /// Dynamic list of all available backgrounds (Base SRD + Custom Homebrew)
  static List<Background> get allBackgrounds => [..._baseBackgrounds, ..._customBackgrounds];

  /// Sets the list of custom/homebrew backgrounds
  static void setCustomBackgrounds(List<Background> custom) {
    _customBackgrounds = List<Background>.from(custom);
  }

  /// Adds or replaces a custom background in the library
  static void addCustomBackground(Background bg) {
    _customBackgrounds.removeWhere((b) => b.id.slug == bg.id.slug);
    _customBackgrounds.add(bg);
  }

  /// Removes a custom background by slug
  static void removeCustomBackground(String slug) {
    _customBackgrounds.removeWhere((b) => b.id.slug == slug);
  }

  static Background? findBySlug(String slug) {
    final clean = slug.toLowerCase().trim();
    return allBackgrounds.where((b) => b.id.slug == clean || b.name.toLowerCase() == clean).firstOrNull;
  }

  /// Canonical 2014 RAW Background Descriptions featuring official Background Features,
  /// proficiencies, and starting equipment without 2024 Origin Feats or Ability Scores.
  static const Map<String, String> _descriptions2014 = {
    'acolyte':
        'You devoted yourself to service in a temple, performing sacred rites and offering sacrifices at the altar of your deity.\n\n'
        '**Feature: Shelter of the Faithful**\n'
        'As an acolyte, you command the respect of those who share your faith, and you can perform the religious ceremonies of your deity. You and your adventuring companions can expect to receive free healing and care at a temple, shrine, or other established presence of your faith, though you must provide any material components needed for spells. Those who share your religion will support you (but only you) at a modest lifestyle.\n\n'
        '**Skill Proficiencies:** Insight, Religion\n'
        '**Languages:** Two of your choice\n'
        '**Starting Equipment:** A holy symbol, a prayer book or prayer wheel, 5 sticks of incense, vestments, a set of common clothes, and a pouch containing 15 GP.',
    'criminal':
        'You have a history of breaking the law and surviving in the criminal underworld through cunning, stealth, and contacts.\n\n'
        '**Feature: Criminal Contact**\n'
        'You have a reliable and trustworthy contact who acts as your liaison to a network of other criminals. You know how to get messages to and from your contact, even over great distances; specifically, you know the local messengers, corrupt caravan masters, and seedy sailors who can deliver messages for you.\n\n'
        '**Skill Proficiencies:** Deception, Stealth\n'
        '**Tool Proficiencies:** Thieves\' Tools, One type of Gaming Set\n'
        '**Starting Equipment:** A crowbar, a set of dark common clothes including a hood, and a pouch containing 15 GP.',
    'entertainer':
        'You thrive in front of an audience, knowing how to entrance, entertain, and inspire crowds of commoners and nobles alike.\n\n'
        '**Feature: By Popular Demand**\n'
        'You can always find a place to perform, usually in an inn or tavern but possibly with a circus, at a theater, or even in a noble\'s court. At such a place, you receive free lodging and food of a modest or comfortable standard, as long as you perform each night. In addition, your performance makes you something of a local figure.\n\n'
        '**Skill Proficiencies:** Acrobatics, Performance\n'
        '**Tool Proficiencies:** Disguise Kit, Musical Instrument (one of your choice)\n'
        '**Starting Equipment:** A musical instrument (one of your choice), the favor of an admirer, costume clothes, and a pouch containing 15 GP.',
    'folk-hero':
        'You come from humble origins, but destiny called you to stand against bullies, monsters, or oppressive local tyrants.\n\n'
        '**Feature: Rustic Hospitality**\n'
        'Since you come from the ranks of the common folk, you fit in among them with ease. You can find a place to hide, rest, or recuperate among other commoners, unless you have shown yourself to be a danger to them. They will shield you from the law or anyone else searching for you, though they will not risk their lives for you.\n\n'
        '**Skill Proficiencies:** Animal Handling, Survival\n'
        '**Tool Proficiencies:** One type of Artisan\'s Tools, Vehicles (Land)\n'
        '**Starting Equipment:** A set of Artisan\'s Tools (one of your choice), a shovel, an iron pot, a set of common clothes, and a pouch containing 10 GP.',
    'guild-artisan':
        'You are a member of an established guild of craftspeople, masters of trade, production, and commerce.\n\n'
        '**Feature: Guild Membership**\n'
        'As an established and respected member of a guild, you can rely on certain benefits that membership provides. Your fellow guild members will provide you with lodging and food if necessary, and pay for your funeral if needed. In most cities and towns, a guildhall offers a central place to meet other members of your profession.\n\n'
        '**Skill Proficiencies:** Insight, Persuasion\n'
        '**Tool Proficiencies:** One type of Artisan\'s Tools\n'
        '**Languages:** One of your choice\n'
        '**Starting Equipment:** A set of Artisan\'s Tools (one of your choice), a letter of introduction from your guild, a set of traveler\'s clothes, and a pouch containing 15 GP.',
    'noble':
        'You were born into wealth, power, and privilege, carrying an aristocratic title and ancestral coat of arms.\n\n'
        '**Feature: Position of Privilege**\n'
        'Thanks to your noble birth, people are inclined to think the best of you. You are welcome in high society, and people assume you have the right to be wherever you are. The common folk make every effort to accommodate you and avoid your displeasure, and other people of high birth treat you as a member of the same social sphere.\n\n'
        '**Skill Proficiencies:** History, Persuasion\n'
        '**Tool Proficiencies:** One type of Gaming Set\n'
        '**Languages:** One of your choice\n'
        '**Starting Equipment:** A set of fine clothes, a signet ring, a scroll of pedigree, and a purse containing 25 GP.',
    'sage':
        'You spent years secluded in libraries and arcane scriptoriums cataloging manuscripts and ancient histories.\n\n'
        '**Feature: Researcher**\n'
        'When you attempt to learn or recall a piece of lore, if you do not know that information, you often know where and from whom you can obtain it. Usually, this information comes from a library, scriptorium, university, or a sage or other learned person or creature.\n\n'
        '**Skill Proficiencies:** Arcana, History\n'
        '**Languages:** Two of your choice\n'
        '**Starting Equipment:** A bottle of black ink, a quill, a small knife, a letter from a dead colleague posing a question you have not yet been able to answer, a set of common clothes, and a pouch containing 10 GP.',
    'sailor':
        'You sailed on seafaring vessels facing stormy gales, sea monsters, and coastal pirates.\n\n'
        '**Feature: Ship\'s Passage**\n'
        'When you need to, you can secure free passage on a sailing ship for yourself and your adventuring companions. You might sail on the ship you served on, or another ship you have good relations with. In return for your free passage, you and your companions are expected to assist the crew during the voyage.\n\n'
        '**Skill Proficiencies:** Athletics, Perception\n'
        '**Tool Proficiencies:** Navigator\'s Tools, Vehicles (Water)\n'
        '**Starting Equipment:** A belaying pin (club), 50 ft of silk rope, a lucky charm, a set of common clothes, and a pouch containing 10 GP.',
    'soldier':
        'You trained in military tactics and discipline, serving on the front lines of defense in warfare.\n\n'
        '**Feature: Military Rank**\n'
        'You have a military rank from your career as a soldier. Soldiers loyal to your former military organization still recognize your authority and influence, and they defer to you if they are of a lower rank. You can invoke your rank to exert influence over other soldiers and requisition simple equipment or horses for temporary use. You can also gain access to friendly military encampments and fortresses.\n\n'
        '**Skill Proficiencies:** Athletics, Intimidation\n'
        '**Tool Proficiencies:** One type of Gaming Set, Vehicles (Land)\n'
        '**Starting Equipment:** An insignia of rank, a trophy taken from a fallen enemy, a set of bone dice or deck of cards, a set of common clothes, and a pouch containing 10 GP.',
    'urchin':
        'You grew up alone on the streets, orphaned and poor, surviving through quick reflexes and sharp wits.\n\n'
        '**Feature: City Secrets**\n'
        'You know the secret patterns and flow to cities and can find passages through the urban sprawl that others would miss. When you are not in combat, you (and companions you lead) can travel between two locations in the city twice as fast as your speed would normally allow.\n\n'
        '**Skill Proficiencies:** Sleight of Hand, Stealth\n'
        '**Tool Proficiencies:** Disguise Kit, Thieves\' Tools\n'
        '**Starting Equipment:** A small knife, a map of the city you grew up in, a pet mouse, a token to remember your parents by, a set of common clothes, and a pouch containing 10 GP.',
  };

  /// Returns the 2014 RAW description with official 2014 features if known.
  static String get2014Description(String slug) {
    final clean = slug.toLowerCase().trim();
    return _descriptions2014[clean] ?? '';
  }

  /// Sanitizes any raw background markdown for 2014 mode by stripping
  /// lines mentioning Origin Feats and Background Ability Scores.
  static String sanitizeFor2014(String markdown) {
    final lines = markdown.split('\n');
    final filtered = lines.where((line) {
      final trimmed = line.trim();
      if (trimmed.startsWith('**Origin Feat:**') ||
          trimmed.startsWith('Origin Feat:') ||
          trimmed.startsWith('**Ability Scores:**') ||
          trimmed.startsWith('Ability Scores:')) {
        return false;
      }
      return true;
    }).toList();
    return filtered.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  }

  /// Returns the ruleset-appropriate description for a background.
  static String getDescriptionForBackground(Background bg, {required RulesetVersion ruleset}) {
    if (ruleset == RulesetVersion.v2014) {
      final desc2014 = get2014Description(bg.id.slug);
      if (desc2014.isNotEmpty) return desc2014;
      return sanitizeFor2014(bg.descriptionMarkdown);
    }
    return bg.descriptionMarkdown;
  }
}
