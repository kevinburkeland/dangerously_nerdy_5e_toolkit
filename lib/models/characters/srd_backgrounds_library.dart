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
}
