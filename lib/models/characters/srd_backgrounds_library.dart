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

  /// Base Core SRD Backgrounds
  static final List<Background> _baseBackgrounds = [
    acolyte,
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
