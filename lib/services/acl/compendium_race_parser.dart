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
    final parsedEntries = transformer.transformEntries(
      raw['trait'] ?? raw['entries'],
      defaultRuleset: ruleset,
    );

    // Subraces
    final subraces = <Subrace>[];
    if (raw['subraces'] is List) {
      for (final rawSub in raw['subraces']) {
        if (rawSub is Map<String, dynamic>) {
          try {
            subraces.add(parseSubrace(rawSub, defaultRaceSlug: slug, forceRuleset: ruleset));
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

    final raceSlug = raw['raceName'] != null
        ? _slugify(raw['raceName'].toString())
        : (raw['raceSlug']?.toString() ?? defaultRaceSlug ?? '');

    final parsedEntries = transformer.transformEntries(
      raw['trait'] ?? raw['entries'],
      defaultRuleset: ruleset,
    );

    final customProperties = <String, dynamic>{};
    raw.forEach((key, value) {
      if (!_standardSubraceKeys.contains(key)) {
        customProperties[key] = value;
      }
    });

    if (raw.containsKey('ability')) customProperties['ability'] = raw['ability'];
    if (raw.containsKey('traitTags')) customProperties['traitTags'] = raw['traitTags'];

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
    'entries',
    'subraces',
  };

  static const Set<String> _standardSubraceKeys = {
    'name',
    'source',
    'raceName',
    'raceSlug',
    'ability',
    'trait',
    'entries',
    'traitTags',
  };

  String _parseSize(dynamic sizeData) {
    if (sizeData is List && sizeData.isNotEmpty) {
      return _mapSizeCode(sizeData.first.toString());
    } else if (sizeData != null) {
      return _mapSizeCode(sizeData.toString());
    }
    return 'Medium';
  }

  String _mapSizeCode(String code) {
    switch (code.toUpperCase()) {
      case 'T':
        return 'Tiny';
      case 'S':
        return 'Small';
      case 'M':
        return 'Medium';
      case 'L':
        return 'Large';
      case 'H':
        return 'Huge';
      case 'G':
        return 'Gargantuan';
      default:
        return code.length > 2 ? code : 'Medium';
    }
  }

  String _parseSpeed(dynamic speedData) {
    if (speedData is String) {
      return speedData.contains('ft') ? speedData : '$speedData ft.';
    }
    if (speedData is num) {
      return '$speedData ft.';
    }
    if (speedData is Map) {
      final walk = speedData['walk'] ?? 30;
      final extra = <String>[];
      speedData.forEach((k, v) {
        if (k != 'walk' && v != null) {
          extra.add('$k ${v is num ? '$v ft.' : v}');
        }
      });
      if (extra.isNotEmpty) {
        return '$walk ft. (${extra.join(', ')})';
      }
      return '$walk ft.';
    }
    return '30 ft.';
  }

  ({
    String? summary,
    Map<String, int> fixedBonuses,
    int flexibleCount,
    int flexibleBonus,
    int bonusFeatCount,
  }) _parseAbilityScores(dynamic abilityData) {
    final fixed = <String, int>{};
    int flexCount = 0;
    int flexBonus = 1;
    int bonusFeats = 0;
    final summaryParts = <String>[];

    if (abilityData is String) {
      return (
        summary: abilityData,
        fixedBonuses: fixed,
        flexibleCount: 0,
        flexibleBonus: 1,
        bonusFeatCount: 0,
      );
    }

    if (abilityData is List) {
      for (final item in abilityData) {
        if (item is Map) {
          _extractFromAbilityMap(item, fixed, (c) => flexCount = c, (b) => flexBonus = b, summaryParts);
        }
      }
    } else if (abilityData is Map) {
      _extractFromAbilityMap(abilityData, fixed, (c) => flexCount = c, (b) => flexBonus = b, summaryParts);
    }

    return (
      summary: summaryParts.isNotEmpty ? summaryParts.join(', ') : null,
      fixedBonuses: fixed,
      flexibleCount: flexCount,
      flexibleBonus: flexBonus,
      bonusFeatCount: bonusFeats,
    );
  }

  void _extractFromAbilityMap(
    Map abilityMap,
    Map<String, int> fixed,
    void Function(int) setFlexCount,
    void Function(int) setFlexBonus,
    List<String> summaryParts,
  ) {
    final stats = ['str', 'dex', 'con', 'int', 'wis', 'cha'];
    for (final s in stats) {
      if (abilityMap[s] is num) {
        final val = (abilityMap[s] as num).toInt();
        fixed[s] = val;
        summaryParts.add('${s.toUpperCase()} ${val >= 0 ? '+$val' : val}');
      }
    }

    if (abilityMap['choose'] is Map) {
      final choose = abilityMap['choose'] as Map;
      final count = (choose['count'] as num?)?.toInt() ?? 1;
      final amt = (choose['amount'] as num?)?.toInt() ?? 1;
      setFlexCount(count);
      setFlexBonus(amt);
      summaryParts.add('Choose $count (+$amt)');
    }
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
