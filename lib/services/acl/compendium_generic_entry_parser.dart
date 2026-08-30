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

    final category = raw['category']?.toString() ??
        raw['featureType']?.toString() ??
        raw['type']?.toString() ??
        defaultCategory;

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
