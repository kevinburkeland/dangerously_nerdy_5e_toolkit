import 'package:flutter/foundation.dart';
import 'package:vtt_engine_core/models/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/homebrew_extended_entities.dart';

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
    customProperties: {
      'startingEquipment': [
        'Holy Symbol',
        'Prayer Book',
        '5 Sticks of Incense',
        'Vestments',
        'Common Clothes',
        'Pouch',
      ],
      'feature': 'Shelter of the Faithful',
      'featureDescription':
          'As an acolyte, you command the respect of those who share your faith, and you can perform the religious ceremonies of your deity. You and your adventuring companions can expect to receive free healing and care at a temple, shrine, or other established presence of your faith, though you must provide any material components needed for spells. Those who share your religion will support you (but only you) at a modest lifestyle.',
      'backgroundFeature': 'Shelter of the Faithful',
    },
  );

  /// Base Core SRD Backgrounds
  static final List<Background> _baseBackgrounds = [
    acolyte,
  ];

  /// Base Core SRD Backgrounds unpolluted by custom backgrounds
  static List<Background> get baseBackgrounds => _baseBackgrounds;

  static List<Background> _customBackgrounds = [];

  /// Dynamic list of custom/homebrew backgrounds registered in the library
  static List<Background> get customBackgrounds =>
      List.unmodifiable(_customBackgrounds);

  /// Dynamic list of all available backgrounds (Base SRD + Custom Homebrew)
  static List<Background> get allBackgrounds =>
      [..._baseBackgrounds, ..._customBackgrounds];

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

  /// Canonical 2014 RAW Background Features
  static const Map<String, ({String name, String description})> _features2014 =
      {
    'acolyte': (
      name: 'Shelter of the Faithful',
      description:
          'As an acolyte, you command the respect of those who share your faith, and you can perform the religious ceremonies of your deity. You and your adventuring companions can expect to receive free healing and care at a temple, shrine, or other established presence of your faith, though you must provide any material components needed for spells. Those who share your religion will support you (but only you) at a modest lifestyle.',
    ),
  };

  /// Canonical 2014 RAW Background Starting Equipment
  static const Map<String, List<String>> _startingEquipment2014 = {
    'acolyte': [
      'Holy Symbol',
      'Prayer Book',
      '5 Sticks of Incense',
      'Vestments',
      'Common Clothes',
      'Pouch',
    ],
  };

  /// Canonical 2014 RAW Background Descriptions featuring official Background Features,
  /// proficiencies, and starting equipment without 2024 Origin Feats or Ability Scores.
  static const Map<String, String> _descriptions2014 = {
    'acolyte': 'You devoted yourself to service in a temple, performing sacred rites and offering sacrifices at the altar of your deity.\n\n'
        '**Feature: Shelter of the Faithful**\n'
        'As an acolyte, you command the respect of those who share your faith, and you can perform the religious ceremonies of your deity. You and your adventuring companions can expect to receive free healing and care at a temple, shrine, or other established presence of your faith, though you must provide any material components needed for spells. Those who share your religion will support you (but only you) at a modest lifestyle.\n\n'
        '**Skill Proficiencies:** Insight, Religion\n'
        '**Languages:** Two of your choice\n'
        '**Starting Equipment:** A holy symbol, a prayer book or prayer wheel, 5 sticks of incense, vestments, a set of common clothes, and a pouch containing 15 GP.',
  };

  /// Finds raw background without recursive decoration.
  static Background? findRawBySlug(String slug) {
    final clean = slug.toLowerCase().trim();
    return allBackgrounds
        .where((b) => b.id.slug == clean || b.name.toLowerCase() == clean)
        .firstOrNull;
  }

  /// Extracts the starting equipment list for 2014 or arbitrary homebrew backgrounds.
  static List<String> extractStartingEquipment(String slug) {
    final clean = slug.toLowerCase().trim();
    if (_startingEquipment2014.containsKey(clean)) {
      return List<String>.from(_startingEquipment2014[clean]!);
    }
    final rawBg = findRawBySlug(clean);
    if (rawBg != null && rawBg.customProperties['startingEquipment'] is List) {
      final list = rawBg.customProperties['startingEquipment'] as List;
      return list.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
    }
    final desc = (rawBg?.descriptionMarkdown.isNotEmpty == true)
        ? rawBg!.descriptionMarkdown
        : get2014Description(clean);
    final match =
        RegExp(r'\*\*Starting Equipment:\*\*\s*([^\n]+)', caseSensitive: false)
            .firstMatch(desc);
    if (match != null) {
      final itemsText = match.group(1)!;
      return itemsText
          .split(RegExp(r',|\band\b'))
          .map((s) => s.trim().replaceAll(
              RegExp(r'^\s*a\s+|^\s*an\s+', caseSensitive: false), ''))
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return const [];
  }

  /// Returns 2014 official or arbitrary homebrew background feature if known.
  static ({String name, String description})? get2014Feature(String slug,
      [Background? bg]) {
    final clean = slug.toLowerCase().trim();
    if (_features2014.containsKey(clean)) {
      return _features2014[clean];
    }
    final targetBg = bg ?? findRawBySlug(clean);
    // 1. Check customProperties
    if (targetBg != null) {
      final name = targetBg.customProperties['backgroundFeature']?.toString() ??
          targetBg.customProperties['feature']?.toString();
      final desc = targetBg.customProperties['backgroundFeatureDescription']
              ?.toString() ??
          targetBg.customProperties['featureDescription']?.toString();
      if (name != null && name.trim().isNotEmpty) {
        return (name: name.trim(), description: desc?.trim() ?? '');
      }
    }

    // 2. Check descriptionMarkdown for feature headings or bold sections
    final markdown = (targetBg?.descriptionMarkdown.isNotEmpty == true)
        ? targetBg!.descriptionMarkdown
        : get2014Description(clean);
    if (markdown.isNotEmpty) {
      final match = RegExp(
            r'(?:###|\*\*)\s*Feature:\s*([^*\n#]+)(?:\*\*|#*)\n+([^\n]+(?:\n\n[^\n]+)*)',
            caseSensitive: false,
          ).firstMatch(markdown) ??
          RegExp(
            r'\*\*Feature:\s*([^*]+)\*\*\n+([^\n]+(?:\n\n[^\n]+)*)',
            caseSensitive: false,
          ).firstMatch(markdown);
      if (match != null) {
        return (
          name: match.group(1)!.trim(),
          description: match.group(2)!.trim()
        );
      }
    }
    return null;
  }

  static Background? findBySlug(String slug) {
    final clean = slug.toLowerCase().trim();
    final bg = findRawBySlug(clean);
    if (bg == null) return null;
    final feature = get2014Feature(clean, bg);
    final equipment = extractStartingEquipment(clean);
    final props = Map<String, dynamic>.from(bg.customProperties);
    if (feature != null) {
      props.putIfAbsent('feature', () => feature.name);
      props.putIfAbsent('featureDescription', () => feature.description);
      props.putIfAbsent('backgroundFeature', () => feature.name);
      props.putIfAbsent(
          'backgroundFeatureDescription', () => feature.description);
    }
    if (equipment.isNotEmpty) {
      props.putIfAbsent('startingEquipment', () => equipment);
    }
    final skills = bg.skillProficiencies.isNotEmpty
        ? bg.skillProficiencies
        : (clean == 'acolyte'
            ? const ['Insight', 'Religion']
            : const <String>[]);
    return bg.copyWith(
      customProperties: props,
      skillProficiencies: skills,
    );
  }

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
  static String getDescriptionForBackground(Background bg,
      {required RulesetVersion ruleset}) {
    if (ruleset == RulesetVersion.v2014) {
      final desc2014 = get2014Description(bg.id.slug);
      var text = desc2014.isNotEmpty
          ? desc2014
          : sanitizeFor2014(bg.descriptionMarkdown);
      final feature = get2014Feature(bg.id.slug, bg);
      if (feature != null &&
          !text.toLowerCase().contains(feature.name.toLowerCase())) {
        final featBlock =
            '**Feature: ${feature.name}**\n${feature.description}';
        text = text.isEmpty ? featBlock : '$text\n\n$featBlock';
      }
      return text;
    }
    return bg.descriptionMarkdown;
  }
}
