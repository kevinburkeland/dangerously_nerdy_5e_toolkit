import '../../models/domain/core_types.dart';
import '../../models/domain/homebrew_extended_entities.dart';
import 'entry_tag_transformer.dart';

/// Anti-Corruption Layer (ACL) dedicated transformer for Community Compendium and Homebrew Optional Features, Rewards, Tables, Hazards, and Conditions.
class CompendiumGenericEntryParser {
  final EntryTagTransformer transformer;

  CompendiumGenericEntryParser({EntryTagTransformer? transformer})
      : transformer = transformer ?? EntryTagTransformer();

  /// Transforms a raw community compendium or homebrew generic JSON entry into a strongly-typed [HomebrewCompendiumEntry].
  HomebrewCompendiumEntry parseGenericEntry(
    Map<String, dynamic> raw, {
    String defaultCategory = 'Custom',
    RulesetVersion? forceRuleset,
  }) {
    final name = raw['name']?.toString().trim() ??
        raw['caption']?.toString().trim() ??
        'Unnamed Entry';
    final slug = _slugify(name);
    final source = raw['source']?.toString().toUpperCase() ?? 'HOMEBREW';
    final ruleset = forceRuleset ?? _mapSourceToRuleset(source);

    final nameLower = name.toLowerCase();
    String category = defaultCategory;
    if (nameLower.startsWith('pact of the') || nameLower.contains('pact boon')) {
      category = 'Pact Boon';
    } else if (raw['category'] != null && raw['category'].toString().isNotEmpty) {
      category = _cleanCategoryString(raw['category'].toString());
    } else if (raw['featureType'] != null) {
      category = _decodeFeatureType(raw['featureType']);
    } else if (raw['type'] != null && raw['type'].toString().isNotEmpty) {
      category = _cleanCategoryString(raw['type'].toString());
    }

    if (nameLower.startsWith('pact of the') || nameLower.contains('pact boon')) {
      category = 'Pact Boon';
    }

    final parsedEntries = transformer.transformEntries(
      raw['entries'] ?? raw['rows'] ?? raw['table'] ?? raw['entry'],
      defaultRuleset: ruleset,
    );

    // Capture auxiliary fields for 0% data loss
    final customProperties = <String, dynamic>{};
    raw.forEach((key, value) {
      if (key != 'name' && key != 'entries' && key != 'source') {
        customProperties[key] = value;
      }
    });

    return HomebrewCompendiumEntry(
      id: EntityId(slug: slug, ruleset: ruleset),
      name: name,
      category: category,
      descriptionMarkdown: parsedEntries.markdown,
      customProperties: customProperties,
    );
  }

  String _decodeFeatureType(dynamic ftData) {
    final str = (ftData is List ? ftData.join(', ') : ftData.toString()).toUpperCase().trim();
    if (str.contains('MV') || str.contains('MANEUVER') || str.contains('BM')) {
      return 'Maneuver';
    }
    if (str.contains('EI') || str.contains('INVOCATION')) {
      return 'Eldritch Invocation';
    }
    if (str.contains('AI') || str.contains('INF') || str.contains('INFUSION')) {
      return 'Infusion';
    }
    if (str.contains('AS') || str.contains('ARCANE SHOT')) {
      return 'Arcane Shot';
    }
    if (str.contains('ED') || str.contains('ELEMENTAL DISCIPLINE')) {
      return 'Elemental Discipline';
    }
    if (str.contains('MM') || str.contains('METAMAGIC')) {
      return 'Metamagic';
    }
    if (str.contains('RN') || str.contains('RUNE')) {
      return 'Rune';
    }
    if (str.contains('FS') || str.contains('FIGHTING STYLE')) {
      return 'Fighting Style';
    }
    if (str.contains('PB') || str.contains('PACT BOON')) {
      return 'Pact Boon';
    }
    return _cleanCategoryString(ftData.toString());
  }

  String _cleanCategoryString(String cat) {
    var c = cat.trim();
    if (c.startsWith('[') && c.endsWith(']')) {
      c = c.substring(1, c.length - 1).trim();
    }
    if (c.startsWith("'") && c.endsWith("'")) {
      c = c.substring(1, c.length - 1).trim();
    }
    if (c.startsWith('"') && c.endsWith('"')) {
      c = c.substring(1, c.length - 1).trim();
    }
    // Check if inner content is a code like MV:B
    final upper = c.toUpperCase();
    if (upper.contains('MV') || upper.contains('MANEUVER') || upper.contains('BM')) {
      return 'Maneuver';
    }
    if (upper.contains('EI') || upper.contains('INVOCATION')) {
      return 'Eldritch Invocation';
    }
    if (upper.contains('AI') || upper.contains('INF') || upper.contains('INFUSION')) {
      return 'Infusion';
    }
    if (upper.contains('AS') || upper.contains('ARCANE SHOT')) {
      return 'Arcane Shot';
    }
    if (upper.contains('ED') || upper.contains('ELEMENTAL DISCIPLINE')) {
      return 'Elemental Discipline';
    }
    if (upper.contains('MM') || upper.contains('METAMAGIC')) {
      return 'Metamagic';
    }
    if (upper.contains('RN') || upper.contains('RUNE')) {
      return 'Rune';
    }
    if (upper.contains('FS') || upper.contains('FIGHTING STYLE')) {
      return 'Fighting Style';
    }
    if (upper.contains('PB') || upper.contains('PACT BOON')) {
      return 'Pact Boon';
    }
    return c.isNotEmpty ? c : 'Custom';
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
