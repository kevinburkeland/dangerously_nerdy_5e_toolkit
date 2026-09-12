import '../../models/domain/core_types.dart';
import '../../models/domain/feature_grant.dart';
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
    final rawPrereq = raw['prerequisite'] ?? raw['prereq'];
    if (rawPrereq is List) {
      prereq = rawPrereq.map((e) {
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
    } else if (rawPrereq != null) {
      prereq = rawPrereq.toString();
    }

    // Category (Origin, General, Fighting Style, Epic Boon)
    final category = _parseCategory(raw);

    // Description Markdown (support entries, desc, description, text)
    final entriesData = raw['entries'] ?? raw['desc'] ?? raw['description'] ?? raw['text'];
    final parsedEntries = transformer.transformEntries(
      entriesData,
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

    // Parse structured Ability Score Improvements (ASI)
    final asi = _parseAbilityScores(raw['ability'] ?? customProperties['ability']);
    if (asi.selectableAbilities.isNotEmpty) {
      customProperties['selectableAbilities'] = asi.selectableAbilities;
      customProperties['statIncreaseAmount'] = asi.amount;
      if (asi.selectableAbilities.length == 1) {
        customProperties['statIncreaseAbility'] = asi.selectableAbilities.first;
      }
    }

    // Extract declarative grants
    final grants = _extractGrants(slug, name, raw, customProperties, asi);

    return Feat(
      id: EntityId(slug: slug, ruleset: ruleset),
      name: name,
      prerequisite: prereq,
      category: category,
      descriptionMarkdown: parsedEntries.markdown,
      grants: grants,
      customProperties: customProperties,
    );
  }

  static const Set<String> _standardFeatKeys = {
    'name',
    'source',
    'prerequisite',
    'prereq',
    'category',
    'featType',
    'entries',
    'desc',
    'description',
    'text',
  };

  String _parseCategory(Map<String, dynamic> raw) {
    if (raw['category'] != null) return raw['category'].toString();
    final ftRaw = raw['featType'];
    if (ftRaw is Map) {
      if (ftRaw['Origin'] == true) return 'Origin';
      if (ftRaw['Fighting Style'] == true) return 'Fighting Style';
      if (ftRaw['Epic Boon'] == true) return 'Epic Boon';
      if (ftRaw.isNotEmpty) return ftRaw.keys.first.toString();
    } else if (ftRaw is List && ftRaw.isNotEmpty) {
      final first = ftRaw.first.toString();
      if (first.toLowerCase().contains('origin')) return 'Origin';
      if (first.toLowerCase().contains('fighting style')) return 'Fighting Style';
      if (first.toLowerCase().contains('boon')) return 'Epic Boon';
      return first;
    } else if (ftRaw != null && ftRaw.toString().isNotEmpty) {
      return ftRaw.toString();
    }
    return 'General';
  }

  ({List<String> selectableAbilities, int amount}) _parseAbilityScores(dynamic rawAbility) {
    final abilities = <String>[];
    int amount = 1;

    void processMap(Map map) {
      map.forEach((k, v) {
        final key = k.toString().toLowerCase().trim();
        if (['str', 'dex', 'con', 'int', 'wis', 'cha', 'strength', 'dexterity', 'constitution', 'intelligence', 'wisdom', 'charisma'].contains(key)) {
          final mapped = _expandAbility(key);
          if (!abilities.contains(mapped)) abilities.add(mapped);
          if (v is num && v.toInt() > 0) amount = v.toInt();
        } else if (key == 'choose' && v is Map) {
          if (v['from'] is List) {
            for (final item in v['from']) {
              final mapped = _expandAbility(item.toString().toLowerCase().trim());
              if (!abilities.contains(mapped)) abilities.add(mapped);
            }
          }
          if (v['amount'] is num) amount = (v['amount'] as num).toInt();
        }
      });
    }

    if (rawAbility is List) {
      for (final item in rawAbility) {
        if (item is Map) processMap(item);
      }
    } else if (rawAbility is Map) {
      processMap(rawAbility);
    }

    return (selectableAbilities: abilities, amount: amount);
  }

  String _expandAbility(String ab) {
    switch (ab) {
      case 'str': return 'strength';
      case 'dex': return 'dexterity';
      case 'con': return 'constitution';
      case 'int': return 'intelligence';
      case 'wis': return 'wisdom';
      case 'cha': return 'charisma';
      default: return ab;
    }
  }

  List<FeatureGrant> _extractGrants(
    String slug,
    String name,
    Map<String, dynamic> raw,
    Map<String, dynamic> custom,
    ({List<String> selectableAbilities, int amount}) asi,
  ) {
    final grants = <FeatureGrant>[];

    // Ability Score Boost (if fixed single ability)
    if (asi.selectableAbilities.length == 1) {
      final ab = asi.selectableAbilities.first;
      grants.add(FeatureGrant.abilityBoost(
        grantId: 'feat-$slug-asi-$ab',
        ability: ab,
        amount: asi.amount,
        label: '+${asi.amount} ${_capitalize(ab)}',
      ));
    }

    // Tough feat HP bonus
    if (slug == 'tough' || name.toLowerCase() == 'tough') {
      grants.add(FeatureGrant.hpBonus(
        grantId: 'feat-$slug-hp',
        perLevel: 2,
        label: '+2 Max HP per Level',
      ));
    }

    // Additional Spells & Inherent Spells
    final addSpells = raw['additionalSpells'] ??
        custom['additionalSpells'] ??
        raw['spells'] ??
        custom['spells'];

    void extractSpellsFromNode(dynamic node) {
      if (node == null) return;
      if (node is String) {
        final spName = node.split('|').first.replaceAll('#c', '').trim();
        if (spName.isNotEmpty && !spName.startsWith('{')) {
          final spSlug = _slugify(spName);
          if (spSlug.isNotEmpty && !grants.any((g) => g.grantId == 'feat-$slug-spell-$spSlug')) {
            grants.add(FeatureGrant.bonusSpell(
              grantId: 'feat-$slug-spell-$spSlug',
              slug: spSlug,
              displayName: spName,
              label: spName,
            ));
          }
        }
      } else if (node is List) {
        for (final item in node) {
          extractSpellsFromNode(item);
        }
      } else if (node is Map) {
        if (node.containsKey('choose')) {
          final ch = node['choose'];
          if (ch is Map && ch['from'] != null) {
            extractSpellsFromNode(ch['from']);
          } else if (ch is String && ch.isNotEmpty) {
            final clean = ch.split('|').first.replaceAll('#c', '').trim();
            if (!clean.contains('=')) {
              extractSpellsFromNode(clean);
            }
          }
        }
        if (node.containsKey('from')) {
          extractSpellsFromNode(node['from']);
        }
        for (final entry in node.entries) {
          final k = entry.key.toString().toLowerCase();
          if (k == 'choose' || k == 'count' || k == 'all' || k == 'from') continue;
          extractSpellsFromNode(entry.value);
        }
      }
    }

    if (addSpells != null) {
      extractSpellsFromNode(addSpells);
    }

    // Skill Proficiencies
    final skills = raw['skillProficiencies'] ?? custom['skillProficiencies'];
    if (skills is List) {
      for (final s in skills) {
        if (s is String && s.isNotEmpty) {
          grants.add(FeatureGrant.skillProficiency(
            s.toLowerCase().trim(),
            grantId: 'feat-$slug-skill-${s.toLowerCase().trim()}',
            label: '${_capitalize(s.trim())} Proficiency',
          ));
        } else if (s is Map && s['choose'] is Map) {
          final chooseMap = s['choose'] as Map;
          final fromList = chooseMap['from'] as List? ?? [];
          final count = (chooseMap['count'] as num?)?.toInt() ?? 1;
          grants.add(FeatureGrant.skillChoice(
            grantId: 'feat-$slug-skill-choice',
            count: count,
            pool: fromList.map((f) => f.toString().toLowerCase().trim()).toList(),
            label: 'Skill Proficiency Choice ($count)',
          ));
        }
      }
    }

    // Tool Proficiencies
    final tools = raw['toolProficiencies'] ?? custom['toolProficiencies'];
    if (tools is List) {
      for (final t in tools) {
        if (t is String && t.isNotEmpty) {
          grants.add(FeatureGrant.weaponArmorProficiency(
            t.trim(),
            grantId: 'feat-$slug-tool-${_slugify(t)}',
            label: '$t Proficiency',
          ));
        } else if (t is Map) {
          t.forEach((toolName, enabled) {
            if (enabled == true || enabled == 1) {
              grants.add(FeatureGrant.weaponArmorProficiency(
                toolName.toString().trim(),
                grantId: 'feat-$slug-tool-${_slugify(toolName.toString())}',
                label: '${toolName.toString().trim()} Proficiency',
              ));
            }
          });
        }
      }
    }

    // Weapon Proficiencies
    final weapons = raw['weaponProficiencies'] ?? custom['weaponProficiencies'];
    if (weapons is List) {
      for (final w in weapons) {
        if (w is String && w.isNotEmpty) {
          grants.add(FeatureGrant.weaponArmorProficiency(
            w.trim(),
            grantId: 'feat-$slug-weapon-${_slugify(w)}',
            label: '$w Proficiency',
          ));
        }
      }
    }

    // Damage resistances
    final resist = raw['resist'] ?? custom['resist'];
    if (resist is List) {
      for (final r in resist) {
        final rStr = r.toString().toLowerCase().trim();
        if (rStr.isNotEmpty) {
          grants.add(FeatureGrant.resistance(
            rStr,
            grantId: 'feat-$slug-resist-$rStr',
            label: 'Resistance to $rStr damage',
          ));
        }
      }
    } else if (resist is String && resist.isNotEmpty) {
      final rStr = resist.toLowerCase().trim();
      grants.add(FeatureGrant.resistance(
        rStr,
        grantId: 'feat-$slug-resist-$rStr',
        label: 'Resistance to $resist damage',
      ));
    }

    return grants;
  }

  String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

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
