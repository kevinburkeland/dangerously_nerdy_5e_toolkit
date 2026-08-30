import '../../models/domain/core_types.dart';
import '../../models/domain/homebrew_extended_entities.dart';
import 'entry_tag_transformer.dart';

/// Anti-Corruption Layer (ACL) dedicated transformer for Community Compendium and Homebrew Races, Species, and Subraces.
class CompendiumRaceParser {
  final EntryTagTransformer transformer;

  CompendiumRaceParser({EntryTagTransformer? transformer})
      : transformer = transformer ?? EntryTagTransformer();

  /// Transforms a raw community compendium or homebrew race/species JSON map into a strongly-typed [Race].
  Race parseRace(Map<String, dynamic> raw, {RulesetVersion? forceRuleset}) {
    final name = raw['name']?.toString().trim() ?? 'Unnamed Race';
    final slug = _slugify(name);
    final source = raw['source']?.toString().toUpperCase() ?? 'PHB';
    final ruleset = forceRuleset ?? _mapSourceToRuleset(source);

    // Size
    final size = _parseSize(raw['size']);

    // Speed
    final speed = _parseSpeed(raw['speed']);

    // Ability Score Parsing (Fixed and Flexible)
    final abilityResult = _parseAbilityScores(raw['ability']);

    // Traits Markdown
    final traitsData = raw['trait'] ?? raw['traits'] ?? raw['entries'] ?? raw['desc'] ?? raw['description'];
    final parsedEntries = transformer.transformEntries(
      traitsData,
      defaultRuleset: ruleset,
    );

    // Subraces
    final subraces = <Subrace>[];
    final rawSubList = raw['subraces'] ?? raw['subrace'];
    if (rawSubList is List) {
      for (final rawSub in rawSubList) {
        if (rawSub is Map) {
          try {
            subraces.add(parseSubrace(Map<String, dynamic>.from(rawSub), defaultRaceSlug: slug, forceRuleset: ruleset));
          } catch (_) {}
        }
      }
    }

    // Auxiliary & 0% data loss properties
    final customProperties = <String, dynamic>{};
    raw.forEach((key, value) {
      if (!_standardRaceKeys.contains(key)) {
        customProperties[key] = value;
      }
    });

    if (raw.containsKey('darkvision')) customProperties['darkvision'] = raw['darkvision'];
    if (raw.containsKey('skillProficiencies')) customProperties['skillProficiencies'] = raw['skillProficiencies'];
    if (raw.containsKey('toolProficiencies')) customProperties['toolProficiencies'] = raw['toolProficiencies'];
    if (raw.containsKey('languageProficiencies')) customProperties['languageProficiencies'] = raw['languageProficiencies'];
    if (raw.containsKey('additionalSpells')) customProperties['additionalSpells'] = raw['additionalSpells'];
    if (raw.containsKey('ability')) customProperties['ability'] = raw['ability'];

    return Race(
      id: EntityId(slug: slug, ruleset: ruleset),
      name: name,
      size: size,
      speed: speed,
      abilityScoreSummary: abilityResult.summary,
      traitsMarkdown: parsedEntries.markdown,
      subraces: subraces,
      bonusFeatCount: abilityResult.bonusFeatCount,
      flexibleAbilityCount: abilityResult.flexibleCount,
      flexibleAbilityBonus: abilityResult.flexibleBonus,
      fixedAbilityBonuses: abilityResult.fixedBonuses,
      customProperties: customProperties,
    );
  }

  /// Transforms a raw community compendium or homebrew subrace JSON map into a strongly-typed [Subrace].
  Subrace parseSubrace(
    Map<String, dynamic> raw, {
    String? defaultRaceSlug,
    RulesetVersion? forceRuleset,
  }) {
    final name = raw['name']?.toString().trim() ?? 'Unnamed Subrace';
    final slug = _slugify(name);
    final source = raw['source']?.toString().toUpperCase() ?? 'PHB';
    final ruleset = forceRuleset ?? _mapSourceToRuleset(source);

    String raceSlug = '';
    if (raw['raceName'] != null && raw['raceName'].toString().isNotEmpty) {
      raceSlug = _slugify(raw['raceName'].toString());
    } else if (raw['race'] != null) {
      if (raw['race'] is Map) {
        raceSlug = _slugify((raw['race'] as Map)['name']?.toString() ?? '');
      } else {
        raceSlug = _slugify(raw['race'].toString());
      }
    } else if (raw['species'] != null) {
      raceSlug = _slugify(raw['species'].toString());
    } else if (raw['raceSlug'] != null && raw['raceSlug'].toString().isNotEmpty) {
      raceSlug = _slugify(raw['raceSlug'].toString());
    } else if (defaultRaceSlug != null && defaultRaceSlug.isNotEmpty) {
      raceSlug = _slugify(defaultRaceSlug);
    }

    final traitsData = raw['trait'] ?? raw['traits'] ?? raw['entries'] ?? raw['desc'] ?? raw['description'];
    final parsedEntries = transformer.transformEntries(
      traitsData,
      defaultRuleset: ruleset,
    );

    final customProperties = <String, dynamic>{};
    raw.forEach((key, value) {
      if (!_standardSubraceKeys.contains(key)) {
        customProperties[key] = value;
      }
    });

    return Subrace(
      id: EntityId(slug: slug, ruleset: ruleset),
      name: name,
      raceSlug: raceSlug,
      traitsMarkdown: parsedEntries.markdown,
      customProperties: customProperties,
    );
  }

  static const Set<String> _standardRaceKeys = {
    'name',
    'source',
    'size',
    'speed',
    'ability',
    'trait',
    'traits',
    'entries',
    'desc',
    'description',
    'subraces',
  };

  static const Set<String> _standardSubraceKeys = {
    'name',
    'source',
    'raceName',
    'raceSlug',
    'trait',
    'traits',
    'entries',
    'desc',
    'description',
  };

  String _parseSize(dynamic sizeData) {
    if (sizeData is List && sizeData.isNotEmpty) {
      return sizeData.map((s) => _mapSize(s.toString())).join(' or ');
    } else if (sizeData is String) {
      return _mapSize(sizeData);
    }
    return 'Medium';
  }

  String _mapSize(String code) {
    switch (code.toUpperCase().trim()) {
      case 'T':
      case 'TINY':
        return 'Tiny';
      case 'S':
      case 'SMALL':
        return 'Small';
      case 'M':
      case 'MEDIUM':
        return 'Medium';
      case 'L':
      case 'LARGE':
        return 'Large';
      default:
        return code;
    }
  }

  String _parseSpeed(dynamic speedData) {
    if (speedData is Map) {
      final walk = speedData['walk'] ?? speedData['speed'] ?? 30;
      final other = <String>[];
      speedData.forEach((k, v) {
        if (k != 'walk' && k != 'speed') {
          other.add('$k $v ft.');
        }
      });
      return '$walk ft.${other.isNotEmpty ? " (${other.join(', ')})" : ""}';
    } else if (speedData is num) {
      return '$speedData ft.';
    } else if (speedData != null) {
      final str = speedData.toString().trim();
      return str.contains('ft') ? str : '$str ft.';
    }
    return '30 ft.';
  }

  ({
    String? summary,
    int bonusFeatCount,
    int flexibleCount,
    int flexibleBonus,
    Map<String, int> fixedBonuses,
  }) _parseAbilityScores(dynamic abilityData) {
    if (abilityData == null) {
      return (
        summary: null,
        bonusFeatCount: 0,
        flexibleCount: 0,
        flexibleBonus: 0,
        fixedBonuses: const {},
      );
    }

    final fixed = <String, int>{};
    int flexCount = 0;
    int flexBonus = 1;
    int featCount = 0;
    final parts = <String>[];

    if (abilityData is List) {
      for (final ab in abilityData) {
        if (ab is Map) {
          ab.forEach((k, v) {
            final key = k.toString().toLowerCase();
            if (['str', 'dex', 'con', 'int', 'wis', 'cha'].contains(key) && v is num) {
              fixed[key.toUpperCase()] = v.toInt();
              parts.add('${key.toUpperCase()} +$v');
            } else if (key == 'choose' && v is Map) {
              final count = (v['count'] as num?)?.toInt() ?? 1;
              final amount = (v['amount'] as num?)?.toInt() ?? 1;
              flexCount += count;
              flexBonus = amount;
              parts.add('+$amount to any $count abilities');
            }
          });
        }
      }
    } else if (abilityData is Map) {
      abilityData.forEach((k, v) {
        final key = k.toString().toLowerCase();
        if (['str', 'dex', 'con', 'int', 'wis', 'cha'].contains(key) && v is num) {
          fixed[key.toUpperCase()] = v.toInt();
          parts.add('${key.toUpperCase()} +$v');
        } else if (key == 'choose' && v is Map) {
          final count = (v['count'] as num?)?.toInt() ?? 1;
          final amount = (v['amount'] as num?)?.toInt() ?? 1;
          flexCount += count;
          flexBonus = amount;
          parts.add('+$amount to any $count abilities');
        }
      });
    }

    return (
      summary: parts.isNotEmpty ? parts.join(', ') : null,
      bonusFeatCount: featCount,
      flexibleCount: flexCount,
      flexibleBonus: flexBonus,
      fixedBonuses: fixed,
    );
  }

  String _slugify(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r"['’]"), '')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }

  RulesetVersion _mapSourceToRuleset(String? source) {
    if (source == null || source.isEmpty) return RulesetVersion.homebrew;
    final s = source.toUpperCase();
    if (s.contains('XPHB') || s.contains('SRD52') || s.contains('2024')) {
      return RulesetVersion.v2024;
    }
    if (s.contains('PHB') || s.contains('SRD') || s.contains('2014')) {
      return RulesetVersion.v2014;
    }
    return RulesetVersion.homebrew;
  }
}
