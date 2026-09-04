import '../../models/domain/core_types.dart';
import '../../models/domain/feature_grant.dart';
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
    final isModernLineage = raw['lineage'] != null ||
        raw['isCustomLineage'] == true ||
        raw['isLineage'] == true ||
        ruleset == RulesetVersion.v2024;

    final abilityResult = _parseAbilityScores(raw['ability'], isModernLineage: isModernLineage);

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

    final grants = _extractGrants(slug, raw, customProperties);

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
      grants: grants,
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
    } else if (raw['_copy'] is Map) {
      final copyObj = raw['_copy'] as Map;
      final rn = copyObj['raceName'] ?? copyObj['name'];
      if (rn != null && rn.toString().isNotEmpty) {
        raceSlug = _slugify(rn.toString());
      }
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
      final rawWalk = speedData['walk'] ?? speedData['speed'] ?? 30;
      final walk = rawWalk is num ? rawWalk.toInt() : (int.tryParse(rawWalk.toString()) ?? 30);
      final other = <String>[];
      speedData.forEach((k, v) {
        if (k != 'walk' && k != 'speed') {
          if (v == true) {
            // Speed mode matches walking speed (e.g. fly: true -> fly 30 ft.)
            other.add('$k $walk ft.');
          } else if (v is num) {
            other.add('$k $v ft.');
          } else if (v is Map) {
            final numVal = v['number'] ?? v['amount'] ?? walk;
            final cond = v['condition'] != null ? ' (${v['condition']})' : '';
            other.add('$k $numVal ft.$cond'.trim());
          } else if (v != false && v != null) {
            final vStr = v.toString().trim();
            other.add(vStr.contains('ft') ? '$k $vStr' : '$k $vStr ft.');
          }
        }
      });
      return '$walk ft.${other.isNotEmpty ? " (${other.join(', ')})" : ""}';
    } else if (speedData is num) {
      return '$speedData ft.';
    } else if (speedData != null) {
      var str = speedData.toString().trim();
      if (str.contains('true ft.')) {
        final match = RegExp(r'^(\d+)\s*ft').firstMatch(str);
        final walkSpeed = match != null ? match.group(1)! : '30';
        str = str.replaceAll('true ft.', '$walkSpeed ft.');
      }
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
  }) _parseAbilityScores(dynamic abilityData, {bool isModernLineage = false}) {
    if (abilityData == null) {
      if (isModernLineage) {
        return (
          summary: '+2/+1 or +1/+1/+1 to any',
          bonusFeatCount: 0,
          flexibleCount: 2,
          flexibleBonus: 1,
          fixedBonuses: const {},
        );
      }
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
      summary: parts.isNotEmpty ? parts.join(', ') : (isModernLineage ? '+2/+1 or +1/+1/+1 to any' : null),
      bonusFeatCount: featCount,
      flexibleCount: flexCount > 0 ? flexCount : (isModernLineage ? 2 : 0),
      flexibleBonus: flexBonus,
      fixedBonuses: fixed,
    );
  }

  List<FeatureGrant> _extractGrants(String slug, Map<String, dynamic> raw, Map<String, dynamic> custom) {
    final grants = <FeatureGrant>[];

    // Darkvision
    final darkvision = raw['darkvision'] ?? custom['darkvision'];
    if (darkvision is num && darkvision > 0) {
      grants.add(FeatureGrant.darkvisionRange(
        darkvision.toInt(),
        grantId: 'race-$slug-darkvision',
        label: 'Darkvision (${darkvision.toInt()} ft.)',
      ));
    } else if (darkvision == true) {
      grants.add(FeatureGrant.darkvisionRange(
        60,
        grantId: 'race-$slug-darkvision',
        label: 'Darkvision (60 ft.)',
      ));
    }

    // Skill Proficiencies
    final skills = raw['skillProficiencies'] ?? custom['skillProficiencies'];
    if (skills is List) {
      for (final s in skills) {
        if (s is String && s.isNotEmpty) {
          grants.add(FeatureGrant.skillProficiency(
            s.toLowerCase().trim(),
            grantId: 'race-$slug-skill-${s.toLowerCase().trim()}',
            label: '$s Proficiency',
          ));
        } else if (s is Map && s['choose'] is Map) {
          final count = (s['choose']['count'] as num?)?.toInt() ?? 1;
          final from = s['choose']['from'] as List?;
          grants.add(FeatureGrant.skillChoice(
            grantId: 'race-$slug-skill-choice',
            count: count,
            pool: from?.map((e) => e.toString()).toList(),
            label: 'Skill Choice ($count)',
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
            t,
            grantId: 'race-$slug-tool-${t.toLowerCase().trim().replaceAll(" ", "-")}',
            label: '$t Proficiency',
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
            grantId: 'race-$slug-resist-$rStr',
            label: 'Resistance to $rStr damage',
          ));
        }
      }
    } else if (resist is String && resist.isNotEmpty) {
      final rStr = resist.toLowerCase().trim();
      grants.add(FeatureGrant.resistance(
        rStr,
        grantId: 'race-$slug-resist-$rStr',
        label: 'Resistance to $resist damage',
      ));
    }

    // Bonus Feat
    final bonusFeat = raw['bonusFeatCount'] ?? custom['bonusFeatCount'];
    if (bonusFeat is num && bonusFeat > 0) {
      grants.add(FeatureGrant(
        type: GrantType.bonusFeat,
        grantId: 'race-$slug-bonus-feat',
        payload: {'category': 'Origin'},
        label: 'Bonus Feat',
      ));
    }

    // Additional Spells
    final addSpells = raw['additionalSpells'] ?? custom['additionalSpells'];
    if (addSpells is List) {
      for (final spGroup in addSpells) {
        if (spGroup is Map) {
          final innate = spGroup['innate'] ?? spGroup['known'];
          if (innate is Map) {
            innate.forEach((lvl, spList) {
              if (spList is List) {
                for (final sp in spList) {
                  final spName = sp.toString().split('|').first.replaceAll('#c', '').trim();
                  final spSlug = spName.toLowerCase().replaceAll(RegExp(r"[^a-z0-9]+"), '-').replaceAll(RegExp(r"^-+|-+$"), '');
                  if (spSlug.isNotEmpty) {
                    grants.add(FeatureGrant.bonusSpell(
                      grantId: 'race-$slug-spell-$spSlug',
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
