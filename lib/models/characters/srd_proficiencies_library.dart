import 'package:flutter/foundation.dart';
import '../domain/character_models.dart' show AbilityType;

/// Category of tool proficiency in 5e rules.
enum ToolCategory {
  artisansTools('Artisan\'s Tools'),
  gamingSets('Gaming Sets'),
  musicalInstruments('Musical Instruments'),
  kits('Kits & Specialized Tools'),
  vehicles('Vehicles');

  final String displayName;
  const ToolCategory(this.displayName);
}

/// Category of language in 5e rules.
enum LanguageCategory {
  standard('Standard Languages'),
  exotic('Exotic Languages'),
  secret('Secret Dialects');

  final String displayName;
  const LanguageCategory(this.displayName);
}

/// Comprehensive SRD library of standard 5e languages and tool proficiencies.
@immutable
class SrdProficienciesLibrary {
  const SrdProficienciesLibrary._();

  // ==========================================
  // LANGUAGES
  // ==========================================

  static const List<String> standardLanguages = [
    'Common',
    'Common Sign Language',
    'Dwarvish',
    'Elvish',
    'Giant',
    'Gnomish',
    'Goblin',
    'Halfling',
    'Orc',
  ];

  static const List<String> exoticLanguages = [
    'Abyssal',
    'Celestial',
    'Deep Speech',
    'Draconic',
    'Infernal',
    'Primordial',
    'Aquan',
    'Auran',
    'Ignan',
    'Terran',
    'Sylvan',
    'Undercommon',
  ];

  static const List<String> secretLanguages = [
    'Druidic',
    'Thieves\' Cant',
  ];

  static List<String> get allLanguages => [
        ...standardLanguages,
        ...exoticLanguages,
        ...secretLanguages,
      ];

  static LanguageCategory getLanguageCategory(String language) {
    final clean = language.trim().toLowerCase();
    if (secretLanguages.any((l) => l.toLowerCase() == clean)) {
      return LanguageCategory.secret;
    }
    if (exoticLanguages.any((l) => l.toLowerCase() == clean)) {
      return LanguageCategory.exotic;
    }
    return LanguageCategory.standard;
  }

  // ==========================================
  // TOOLS
  // ==========================================

  static const List<String> artisansTools = [
    'Alchemist\'s Supplies',
    'Brewer\'s Supplies',
    'Calligrapher\'s Supplies',
    'Carpenter\'s Tools',
    'Cartographer\'s Tools',
    'Cobbler\'s Tools',
    'Cook\'s Utensils',
    'Glassblower\'s Tools',
    'Jeweler\'s Tools',
    'Leatherworker\'s Tools',
    'Mason\'s Tools',
    'Painter\'s Supplies',
    'Potter\'s Tools',
    'Smith\'s Tools',
    'Tinker\'s Tools',
    'Weaver\'s Tools',
    'Woodcarver\'s Tools',
  ];

  static const List<String> gamingSets = [
    'Dice Set',
    'Dragonchess Set',
    'Playing Card Set',
    'Three-Dragon Ante Set',
  ];

  static const List<String> musicalInstruments = [
    'Bagpipes',
    'Drum',
    'Dulcimer',
    'Flute',
    'Horn',
    'Lute',
    'Lyre',
    'Pan Flute',
    'Shawm',
    'Viol',
  ];

  static const List<String> kitsAndSpecialized = [
    'Disguise Kit',
    'Forgery Kit',
    'Herbalism Kit',
    'Navigator\'s Tools',
    'Poisoner\'s Kit',
    'Thieves\' Tools',
  ];

  static const List<String> vehicles = [
    'Vehicles (Land)',
    'Vehicles (Water)',
    'Vehicles (Air)',
  ];

  static List<String> get allTools => [
        ...artisansTools,
        ...gamingSets,
        ...musicalInstruments,
        ...kitsAndSpecialized,
        ...vehicles,
      ];

  static ToolCategory getToolCategory(String tool) {
    final clean = tool.trim().toLowerCase();
    if (artisansTools.any((t) => t.toLowerCase() == clean)) {
      return ToolCategory.artisansTools;
    }
    if (gamingSets.any((t) => t.toLowerCase() == clean)) {
      return ToolCategory.gamingSets;
    }
    if (musicalInstruments.any((t) => t.toLowerCase() == clean)) {
      return ToolCategory.musicalInstruments;
    }
    if (vehicles.any((t) => t.toLowerCase() == clean)) {
      return ToolCategory.vehicles;
    }
    return ToolCategory.kits;
  }

  /// Recommended primary [AbilityType] associated with a tool check according to 5e rules.
  static AbilityType getRecommendedAbility(String tool) {
    final clean = tool.trim().toLowerCase();
    if (clean.contains('thieves')) return AbilityType.dexterity;
    if (clean.contains('herbalism')) return AbilityType.wisdom;
    if (clean.contains('disguise')) return AbilityType.charisma;
    if (clean.contains('forgery')) return AbilityType.dexterity;
    if (clean.contains('poisoner')) return AbilityType.intelligence;
    if (clean.contains('navigator')) return AbilityType.wisdom;
    if (clean.contains('alchemist')) return AbilityType.intelligence;
    if (clean.contains('calligrapher')) return AbilityType.dexterity;
    if (clean.contains('smith') || clean.contains('mason')) return AbilityType.strength;
    if (clean.contains('cook') || clean.contains('brewer')) return AbilityType.wisdom;
    if (musicalInstruments.any((i) => i.toLowerCase() == clean)) return AbilityType.charisma;
    if (gamingSets.any((g) => g.toLowerCase() == clean)) return AbilityType.wisdom;
    if (vehicles.any((v) => v.toLowerCase() == clean)) return AbilityType.dexterity;
    return AbilityType.dexterity;
  }
}
