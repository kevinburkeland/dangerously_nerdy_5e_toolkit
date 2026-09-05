import '../../models/characters/srd_backgrounds_library.dart';
import '../../models/domain/core_types.dart';
import '../../models/domain/feature_grant.dart';
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

    // Resolve base background from _copy if present
    final base = _resolveBaseBackground(raw);

    // Origin Feat
    final originFeat = _parseOriginFeat(raw['originFeat'] ?? raw['feat'] ?? raw['feats'] ?? base?.originFeat);

    // Ability Score Summary (2024 rules)
    final abilitySummary = _parseAbilitySummary(raw['ability'] ?? base?.abilityScoreSummary);

    // Proficiencies
    final skillProficiencies = _parseProficiencies(raw['skillProficiencies'] ?? base?.skillProficiencies);
    final toolProficiencies = _parseProficiencies(raw['toolProficiencies'] ?? base?.toolProficiencies);
    final languages = _parseProficiencies(raw['languageProficiencies'] ?? base?.languages);

    // Markdown description entries (support entries, desc, description, text, or _copy._mod)
    final modEntries = raw['_copy'] is Map ? _extractModEntries((raw['_copy'] as Map)['_mod']) : null;
    final entriesData = raw['entries'] ?? raw['desc'] ?? raw['description'] ?? raw['text'] ?? modEntries;

    final parsedEntries = transformer.transformEntries(
      entriesData,
      defaultRuleset: ruleset,
    );

    var description = parsedEntries.markdown;
    if (description.isEmpty && base != null) {
      description = base.descriptionMarkdown;
    } else if (description.isNotEmpty && base != null && !description.contains(base.name)) {
      description = '$description\n\n${base.descriptionMarkdown}';
    }

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
    if (raw.containsKey('additionalSpells')) customProperties['additionalSpells'] = raw['additionalSpells'];

    final grants = _extractGrants(slug, skillProficiencies, toolProficiencies, languages, originFeat, raw);

    return Background(
      id: EntityId(slug: slug, ruleset: ruleset),
      name: name,
      abilityScoreSummary: abilitySummary,
      originFeat: originFeat,
      skillProficiencies: skillProficiencies,
      toolProficiencies: toolProficiencies,
      languages: languages,
      descriptionMarkdown: description,
      grants: grants,
      customProperties: customProperties,
    );
  }

  static const Set<String> _standardBackgroundKeys = {
    'name',
    'source',
    'feat',
    'feats',
    'originFeat',
    'ability',
    'skillProficiencies',
    'toolProficiencies',
    'languageProficiencies',
    'entries',
    'desc',
    'description',
    'text',
  };

  Background? _resolveBaseBackground(Map<String, dynamic> raw) {
    if (raw['_copy'] is! Map) return null;
    final copyName = (raw['_copy'] as Map)['name']?.toString().toLowerCase().trim() ?? '';
    if (copyName.isEmpty) return null;
    return SrdBackgroundsLibrary.allBackgrounds.where((b) {
      final bName = b.name.toLowerCase();
      return bName == copyName ||
          bName.contains(copyName) ||
          copyName.contains(bName) ||
          b.id.slug == _slugify(copyName);
    }).firstOrNull;
  }

  dynamic _extractModEntries(dynamic mod) {
    if (mod is Map && mod['entries'] != null) {
      final e = mod['entries'];
      if (e is Map && e['items'] != null) return e['items'];
      if (e is List) {
        final list = [];
        for (final item in e) {
          if (item is Map && item['items'] != null) {
            final subItems = item['items'];
            if (subItems is List) {
              list.addAll(subItems);
            } else {
              list.add(subItems);
            }
          }
        }
        if (list.isNotEmpty) return list;
      }
    }
    return null;
  }

  String? _parseOriginFeat(dynamic featData) {
    if (featData == null) return null;
    String? rawFeat;
    if (featData is String) {
      rawFeat = featData;
    } else if (featData is List && featData.isNotEmpty) {
      final first = featData.first;
      if (first is String) {
        rawFeat = first;
      } else if (first is Map) {
        rawFeat = first['feat']?.toString() ?? first['name']?.toString() ?? first.keys.first.toString();
      }
    } else if (featData is Map) {
      rawFeat = featData['feat']?.toString() ?? featData['name']?.toString() ?? featData.keys.first.toString();
    }
    if (rawFeat == null || rawFeat.isEmpty) return null;

    // Strip source pipe e.g. "magic initiate|phb" -> "magic initiate"
    final clean = rawFeat.split('|').first.trim();
    if (clean.isEmpty) return null;
    // Title case words
    return clean.split(' ').map((w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : '').join(' ');
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
      return '+2/+1 or +1/+1/+1 (${keys.join(', ')})';
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
            if (v == true) results.add(k.toString());
            if (k == 'choose' && v is Map) {
              final count = v['count'] ?? 1;
              results.add('Choose $count');
            }
          });
        }
      }
    } else if (profData is String) {
      results.add(profData);
    }
    return results;
  }

  List<FeatureGrant> _extractGrants(
    String slug,
    List<String> skills,
    List<String> tools,
    List<String> languages,
    String? originFeat,
    Map<String, dynamic> raw,
  ) {
    final grants = <FeatureGrant>[];
    for (final s in skills) {
      final clean = s.toLowerCase().trim();
      if (clean.isNotEmpty && !clean.startsWith('choose')) {
        grants.add(FeatureGrant.skillProficiency(
          clean,
          grantId: 'bg-$slug-skill-$clean',
          label: '$s Proficiency',
        ));
      }
    }
    for (final t in tools) {
      final clean = t.trim();
      if (clean.isNotEmpty && !clean.startsWith('choose')) {
        grants.add(FeatureGrant.weaponArmorProficiency(
          clean,
          grantId: 'bg-$slug-tool-${clean.toLowerCase().replaceAll(RegExp(r"[^a-z0-9]+"), "-")}',
          label: '$clean Proficiency',
        ));
      }
    }
    if (originFeat != null && originFeat.isNotEmpty) {
      grants.add(FeatureGrant(
        type: GrantType.bonusFeat,
        grantId: 'bg-$slug-feat',
        payload: {'feat': originFeat, 'category': 'Origin'},
        label: originFeat,
      ));
    }
    // Additional Spells (e.g. setting-specific guild backgrounds)
    final addSpells = raw['additionalSpells'];
    if (addSpells is List) {
      for (final spGroup in addSpells) {
        if (spGroup is Map) {
          final expanded = spGroup['expanded'] ?? spGroup['innate'] ?? spGroup['known'];
          if (expanded is Map) {
            expanded.forEach((lvl, spList) {
              if (spList is List) {
                for (final sp in spList) {
                  final spName = sp.toString().split('|').first.replaceAll('#c', '').trim();
                  final spSlug = spName.toLowerCase().replaceAll(RegExp(r"[^a-z0-9]+"), '-').replaceAll(RegExp(r"^-+|-+$"), '');
                  if (spSlug.isNotEmpty) {
                    grants.add(FeatureGrant.bonusSpell(
                      grantId: 'bg-$slug-spell-$spSlug',
                      slug: spSlug,
                      displayName: spName,
                      label: spName,
                    ));
                  }
                }
              }
            });
          }
        }
      }
    }
    return grants;
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
