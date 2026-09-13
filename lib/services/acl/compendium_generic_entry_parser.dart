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
    final rawCat = (raw['category'] ?? raw['type'] ?? defaultCategory).toString().toLowerCase();
    String category = defaultCategory;
    if (nameLower.startsWith('pact of the') || nameLower.contains('pact boon')) {
      category = 'Pact Boon';
    } else if (raw['featureType'] != null) {
      category = _decodeFeatureType(raw['featureType']);
    } else if (rawCat.contains('table')) {
      category = 'Table';
    } else if (rawCat.contains('deity') || raw.containsKey('pantheon')) {
      category = 'Deity';
    } else if (rawCat.contains('vehicle')) {
      category = 'Vehicle';
    } else if (rawCat.contains('trap')) {
      category = 'Trap';
    } else if (rawCat.contains('hazard')) {
      category = 'Hazard';
    } else if (rawCat.contains('reward') || rawCat.contains('boon') || rawCat.contains('cult')) {
      category = 'Reward';
    } else if (rawCat.contains('condition') || rawCat.contains('status')) {
      category = 'Condition';
    } else if (rawCat.contains('disease')) {
      category = 'Disease';
    } else if (rawCat.contains('action')) {
      category = 'Action';
    } else if (raw['category'] != null && raw['category'].toString().isNotEmpty) {
      category = _cleanCategoryString(raw['category'].toString());
    } else if (raw['type'] != null && raw['type'].toString().isNotEmpty) {
      category = _cleanCategoryString(raw['type'].toString());
    }

    final parsedEntries = transformer.transformEntries(
      raw['entries'] ?? raw['entry'],
      defaultRuleset: ruleset,
    );

    String desc = parsedEntries.markdown;

    // Render rollable table markdown if raw table data is present
    if (desc.isEmpty && raw['rows'] is List) {
      final rows = raw['rows'] as List;
      final colLabels = raw['colLabels'] is List ? (raw['colLabels'] as List) : [];
      if (rows.isNotEmpty) {
        final buffer = StringBuffer();
        if (colLabels.isNotEmpty) {
          buffer.writeln('| ${colLabels.map((c) => c.toString()).join(' | ')} |');
          buffer.writeln('| ${colLabels.map((_) => ':---').join(' | ')} |');
        } else {
          final colCount = (rows.first is List) ? (rows.first as List).length : 1;
          buffer.writeln('| ${List.generate(colCount, (i) => 'Col ${i + 1}').join(' | ')} |');
          buffer.writeln('| ${List.generate(colCount, (_) => ':---').join(' | ')} |');
        }
        for (final r in rows) {
          if (r is List) {
            buffer.writeln('| ${r.map((c) => c.toString()).join(' | ')} |');
          } else {
            buffer.writeln('| ${r.toString()} |');
          }
        }
        desc = buffer.toString().trim();
      }
    }

    // Render deity metadata header
    if (category == 'Deity' || raw.containsKey('pantheon')) {
      category = 'Deity';
      final parts = <String>[];
      if (raw['pantheon'] != null) parts.add('**Pantheon:** ${raw['pantheon']}');
      if (raw['alignment'] != null) {
        final align = raw['alignment'] is List ? (raw['alignment'] as List).join('') : raw['alignment'].toString();
        parts.add('**Alignment:** $align');
      }
      if (raw['domains'] != null) {
        final doms = raw['domains'] is List ? (raw['domains'] as List).join(', ') : raw['domains'].toString();
        parts.add('**Domains:** $doms');
      }
      if (raw['symbol'] != null) parts.add('**Symbol:** ${raw['symbol']}');
      if (parts.isNotEmpty) {
        desc = desc.isNotEmpty ? '${parts.join(' | ')}\n\n$desc' : parts.join(' | ');
      }
    }

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
      descriptionMarkdown: desc,
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
