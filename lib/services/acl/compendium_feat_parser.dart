import '../../models/domain/core_types.dart';
import '../../models/domain/homebrew_extended_entities.dart';
import 'entry_tag_transformer.dart';

/// Anti-Corruption Layer (ACL) dedicated transformer for Community Compendium and Homebrew Feats.
class CompendiumFeatParser {
  final EntryTagTransformer transformer;

  CompendiumFeatParser({EntryTagTransformer? transformer})
      : transformer = transformer ?? EntryTagTransformer();

  /// Transforms a raw community compendium or homebrew feat JSON map into a strongly-typed [Feat].
  Feat parseFeat(Map<String, dynamic> raw, {RulesetVersion? forceRuleset}) {
    final name = raw['name']?.toString().trim() ?? 'Unnamed Feat';
    final slug = _slugify(name);
    final source = raw['source']?.toString().toUpperCase() ?? 'PHB';
    final ruleset = forceRuleset ?? _mapSourceToRuleset(source);

    // Prerequisite
    String? prereq;
    if (raw['prerequisite'] is List) {
      prereq = (raw['prerequisite'] as List).map((e) {
        if (e is Map) {
          final parts = <String>[];
          if (e['level'] != null) parts.add('Level ${e['level']}');
          if (e['ability'] is List) {
            final ab = (e['ability'] as List).map((a) => a.toString()).join(' or ');
            parts.add(ab);
          }
          if (e['spellcasting'] == true) parts.add('Spellcasting');
          if (e['armor'] != null) parts.add('${e['armor']} proficiency');
          if (e['other'] != null) parts.add(e['other'].toString());
          return parts.join(', ');
        }
        return e.toString();
      }).join('; ');
    } else if (raw['prerequisite'] != null) {
      prereq = raw['prerequisite'].toString();
    }

    // Category (Origin, General, Fighting Style, Epic Boon)
    final category = _parseCategory(raw);

    // Description Markdown
    final parsedEntries = transformer.transformEntries(
      raw['entries'],
      defaultRuleset: ruleset,
    );

    // Auxiliary & 0% data loss properties
    final customProperties = <String, dynamic>{};
    raw.forEach((key, value) {
      if (!_standardFeatKeys.contains(key)) {
        customProperties[key] = value;
      }
    });

    if (raw.containsKey('ability')) customProperties['ability'] = raw['ability'];
    if (raw.containsKey('repeatable')) customProperties['repeatable'] = raw['repeatable'];
    if (raw.containsKey('category')) customProperties['category'] = raw['category'];

    return Feat(
      id: EntityId(slug: slug, ruleset: ruleset),
      name: name,
      prerequisite: prereq,
      category: category,
      descriptionMarkdown: parsedEntries.markdown,
      customProperties: customProperties,
    );
  }

  static const Set<String> _standardFeatKeys = {
    'name',
    'source',
    'prerequisite',
    'category',
    'featType',
    'entries',
  };

  String _parseCategory(Map<String, dynamic> raw) {
    if (raw['category'] != null) return raw['category'].toString();
    if (raw['featType'] is Map) {
      final ft = raw['featType'] as Map;
      if (ft['Origin'] == true) return 'Origin';
      if (ft['Fighting Style'] == true) return 'Fighting Style';
      if (ft['Epic Boon'] == true) return 'Epic Boon';
    }
    final cat = raw['featType']?.toString();
    if (cat != null && cat.isNotEmpty) return cat;
    return 'General';
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
