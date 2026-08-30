import '../../models/domain/core_types.dart';
import '../../models/domain/homebrew_extended_entities.dart';
import 'entry_tag_transformer.dart';

/// Anti-Corruption Layer (ACL) dedicated transformer for Community Compendium and Homebrew Backgrounds.
class CompendiumBackgroundParser {
  final EntryTagTransformer transformer;

  CompendiumBackgroundParser({EntryTagTransformer? transformer})
      : transformer = transformer ?? EntryTagTransformer();

  /// Transforms a raw community compendium or homebrew background JSON map into a strongly-typed [Background].
  Background parseBackground(Map<String, dynamic> raw, {RulesetVersion? forceRuleset}) {
    final name = raw['name']?.toString().trim() ?? 'Unnamed Background';
    final slug = _slugify(name);
    final source = raw['source']?.toString().toUpperCase() ?? 'PHB';
    final ruleset = forceRuleset ?? _mapSourceToRuleset(source);

    // Origin Feat
    final originFeat = _parseOriginFeat(raw['feat'] ?? raw['feats']);

    // Ability Score Summary (2024 rules)
    final abilitySummary = _parseAbilitySummary(raw['ability']);

    // Proficiencies
    final skillProficiencies = _parseProficiencies(raw['skillProficiencies']);
    final toolProficiencies = _parseProficiencies(raw['toolProficiencies']);
    final languages = _parseProficiencies(raw['languageProficiencies']);

    // Markdown description entries
    final parsedEntries = transformer.transformEntries(
      raw['entries'],
      defaultRuleset: ruleset,
    );

    // Auxiliary & 0% data loss properties
    final customProperties = <String, dynamic>{};
    raw.forEach((key, value) {
      if (!_standardBackgroundKeys.contains(key)) {
        customProperties[key] = value;
      }
    });

    if (raw.containsKey('startingEquipment')) customProperties['startingEquipment'] = raw['startingEquipment'];
    if (raw.containsKey('ability')) customProperties['ability'] = raw['ability'];
    if (raw.containsKey('backgroundFeature')) customProperties['backgroundFeature'] = raw['backgroundFeature'];

    return Background(
      id: EntityId(slug: slug, ruleset: ruleset),
      name: name,
      abilityScoreSummary: abilitySummary,
      originFeat: originFeat,
      skillProficiencies: skillProficiencies,
      toolProficiencies: toolProficiencies,
      languages: languages,
      descriptionMarkdown: parsedEntries.markdown,
      customProperties: customProperties,
    );
  }

  static const Set<String> _standardBackgroundKeys = {
    'name',
    'source',
    'feat',
    'feats',
    'ability',
    'skillProficiencies',
    'toolProficiencies',
    'languageProficiencies',
    'entries',
  };

  String? _parseOriginFeat(dynamic featData) {
    if (featData == null) return null;
    if (featData is String) return featData;
    if (featData is List && featData.isNotEmpty) {
      final first = featData.first;
      if (first is String) return first;
      if (first is Map) return first.keys.first.toString();
    }
    if (featData is Map) {
      return featData.keys.first.toString();
    }
    return null;
  }

  String? _parseAbilitySummary(dynamic abilityData) {
    if (abilityData == null) return null;
    if (abilityData is String) return abilityData;
    if (abilityData is List) {
      final parts = <String>[];
      for (final item in abilityData) {
        if (item is Map) {
          final keys = item.keys.map((k) => k.toString().toUpperCase()).toList();
          parts.add('+2/+1 or +1/+1/+1 (${keys.join(', ')})');
        }
      }
      return parts.isNotEmpty ? parts.join('; ') : null;
    }
    if (abilityData is Map) {
      final keys = abilityData.keys.map((k) => k.toString().toUpperCase()).toList();
      return keys.join(', ');
    }
    return null;
  }

  List<String> _parseProficiencies(dynamic profData) {
    final results = <String>[];
    if (profData is List) {
      for (final item in profData) {
        if (item is String) {
          results.add(item);
        } else if (item is Map) {
          item.forEach((k, v) {
            if (v == true) {
              results.add(k.toString());
            } else if (k == 'choose') {
              if (v is Map && v['from'] is List) {
                results.add('Choose from: ${(v['from'] as List).join(', ')}');
              }
            } else {
              results.add(k.toString());
            }
          });
        }
      }
    }
    return results;
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
