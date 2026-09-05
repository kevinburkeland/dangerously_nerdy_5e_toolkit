import 'dart:convert';
import '../../models/domain/core_types.dart';
import '../../models/domain/entity_reference.dart';
import '../../models/domain/spell_monster_equipment.dart';
import '../../models/monster_codex_data.dart';
import 'entry_tag_transformer.dart';

/// Anti-Corruption Layer (ACL) dedicated transformer for Community Compendium and Homebrew Monsters/NPCs.
class CompendiumMonsterParser {
  final EntryTagTransformer transformer;

  CompendiumMonsterParser({EntryTagTransformer? transformer})
      : transformer = transformer ?? EntryTagTransformer();

  /// Transforms a raw community compendium or homebrew monster JSON map into a strongly-typed [Monster].
  Monster parseMonster(
    Map<String, dynamic> rawInput, {
    RulesetVersion? forceRuleset,
    Map<String, dynamic>? Function(String name, String? source)? baseLookup,
  }) {
    final raw = resolveCopy(rawInput, baseLookup: baseLookup);
    final name = raw['name']?.toString().trim() ?? 'Unnamed Monster';
    final slug = _slugify(name);
    final source = raw['source']?.toString().toUpperCase() ?? 'MM';
    final ruleset = forceRuleset ?? _mapSourceToRuleset(source);

    // Size
    final size = _parseSize(raw['size']);

    // Type
    final typeStr = _parseType(raw['type']);

    // Alignment
    final alignment = _parseAlignment(raw['alignment']);

    // AC
    final ac = _parseArmorClass(raw['ac']);

    // HP & Hit Die Formula
    final hpData = _parseHitPoints(raw['hp']);

    // CR
    final cr = _parseChallengeRating(raw['cr']);

    // Action Economy & Markdown Generation
    final actionsBuffer = StringBuffer();
    final attackMath = <EvaluationMath>[];
    final innateSpells = <EntityReference<Spell>>[];

    // Speed
    final speedStr = _parseSpeed(raw['speed']);

    // Stats and Saves
    final statsStr = _formatAbilityScores(raw);
    actionsBuffer.writeln('**Speed:** $speedStr\n');
    actionsBuffer.writeln('$statsStr\n');

    // Defenses, Senses, Languages
    _appendDefensesAndSenses(raw, actionsBuffer);

    // Traits
    final traits = (raw['trait'] is List ? raw['trait'] : raw['traits']) as List?;
    if (traits != null && traits.isNotEmpty) {
      actionsBuffer.writeln('### Traits');
      for (final trait in traits) {
        _appendActionOrTrait(trait, actionsBuffer, attackMath, ruleset, defaultTitle: 'Trait');
      }
    }

    // Spellcasting
    final spellcasting = raw['spellcasting'] as List?;
    if (spellcasting != null && spellcasting.isNotEmpty) {
      actionsBuffer.writeln('### Spellcasting');
      for (final sc in spellcasting) {
        if (sc is Map) {
          final scName = sc['name'] ?? 'Spellcasting';
          final headerEntries = sc['headerEntries'] as List?;
          if (headerEntries != null) {
            final parsedHeader = transformer.transformEntries(headerEntries, defaultRuleset: ruleset);
            actionsBuffer.writeln('**$scName**: ${parsedHeader.markdown}\n');
          }
          // Spells by level / daily spells
          final will = sc['will'] as List?;
          if (will != null && will.isNotEmpty) {
            final spellNames = _extractSpellNames(will, innateSpells, ruleset);
            actionsBuffer.writeln('- **At will:** ${spellNames.join(', ')}');
          }
          final daily = sc['daily'] as Map?;
          if (daily != null) {
            daily.forEach((freq, list) {
              if (list is List) {
                final spellNames = _extractSpellNames(list, innateSpells, ruleset);
                final cleanFreq = freq.toString().replaceAll(RegExp(r'[eE]$'), '').replaceAll('/d', '').trim();
                actionsBuffer.writeln('- **$cleanFreq/day each:** ${spellNames.join(', ')}');
              }
            });
          }
          final spellsObj = sc['spells'] as Map?;
          if (spellsObj != null) {
            spellsObj.forEach((lvl, data) {
              if (data is Map && data['spells'] is List) {
                final spellNames = _extractSpellNames(data['spells'] as List, innateSpells, ruleset);
                final slots = data['slots'] != null ? ' (${data['slots']} slots)' : '';
                final lvlNum = int.tryParse(lvl.toString()) ?? 0;
                final lvlLabel = lvlNum == 0 ? 'Cantrips (at will)' : 'Level $lvl$slots';
                actionsBuffer.writeln('- **$lvlLabel:** ${spellNames.join(', ')}');
              }
            });
          }
          actionsBuffer.writeln();
        }
      }
    }

    // Actions
    final actions = (raw['action'] is List ? raw['action'] : raw['actions']) as List?;
    if (actions != null && actions.isNotEmpty) {
      actionsBuffer.writeln('### Actions');
      for (final action in actions) {
        _appendActionOrTrait(action, actionsBuffer, attackMath, ruleset, defaultTitle: 'Action');
      }
    }

    // Bonus Actions
    final bonus = (raw['bonus'] is List ? raw['bonus'] : raw['bonusActions']) as List?;
    if (bonus != null && bonus.isNotEmpty) {
      actionsBuffer.writeln('### Bonus Actions');
      for (final b in bonus) {
        _appendActionOrTrait(b, actionsBuffer, attackMath, ruleset, defaultTitle: 'Bonus Action');
      }
    }

    // Reactions
    final reactions = (raw['reaction'] is List ? raw['reaction'] : raw['reactions']) as List?;
    if (reactions != null && reactions.isNotEmpty) {
      actionsBuffer.writeln('### Reactions');
      for (final r in reactions) {
        _appendActionOrTrait(r, actionsBuffer, attackMath, ruleset, defaultTitle: 'Reaction');
      }
    }

    // Legendary Actions
    final legendary = (raw['legendary'] is List ? raw['legendary'] : raw['legendaryActions']) as List?;
    if (legendary != null && legendary.isNotEmpty) {
      actionsBuffer.writeln('### Legendary Actions');
      final legHeader = raw['legendaryHeader'] as List?;
      if (legHeader != null) {
        final parsedHeader = transformer.transformEntries(legHeader, defaultRuleset: ruleset);
        actionsBuffer.writeln('${parsedHeader.markdown}\n');
      } else {
        final count = (raw['legendaryActions'] as num?)?.toInt() ?? 3;
        actionsBuffer.writeln('The creature can take $count legendary actions, choosing from the options below.\n');
      }
      for (final leg in legendary) {
        _appendActionOrTrait(leg, actionsBuffer, attackMath, ruleset, defaultTitle: 'Option');
      }
    }

    // Capture auxiliary metadata in customProperties for 0% data loss
    final customProperties = <String, dynamic>{};
    raw.forEach((key, value) {
      if (!_standardMonsterKeys.contains(key)) {
        customProperties[key] = value;
      }
    });

    // Explicitly preserve speed & ability scores in standard & suffixed forms
    customProperties['speed'] = speedStr;
    customProperties['str'] = raw['str'] ?? 10;
    customProperties['dex'] = raw['dex'] ?? 10;
    customProperties['con'] = raw['con'] ?? 10;
    customProperties['int'] = raw['int'] ?? 10;
    customProperties['wis'] = raw['wis'] ?? 10;
    customProperties['cha'] = raw['cha'] ?? 10;
    customProperties['strScore'] = customProperties['str'];
    customProperties['dexScore'] = customProperties['dex'];
    customProperties['conScore'] = customProperties['con'];
    customProperties['intScore'] = customProperties['int'];
    customProperties['wisScore'] = customProperties['wis'];
    customProperties['chaScore'] = customProperties['cha'];

    // Preserved friendly formatted strings for defenses, senses, skills, languages
    if (raw['save'] is Map) {
      customProperties['savingThrows'] = (raw['save'] as Map).entries.map((e) => '${e.key.toString().toUpperCase()} ${e.value}').join(', ');
    } else if (raw['savingThrows'] != null) {
      customProperties['savingThrows'] = raw['savingThrows'].toString();
    }
    if (raw['skill'] is Map) {
      customProperties['skills'] = (raw['skill'] as Map).entries.map((e) => '${e.key} ${e.value}').join(', ');
    } else if (raw['skills'] != null) {
      customProperties['skills'] = raw['skills'].toString();
    }
    if (raw['vulnerable'] != null) {
      customProperties['damageVulnerabilities'] = _formatList(raw['vulnerable']);
    } else if (raw['damageVulnerabilities'] != null) {
      customProperties['damageVulnerabilities'] = raw['damageVulnerabilities'].toString();
    }
    if (raw['resist'] != null) {
      customProperties['damageResistances'] = _formatList(raw['resist']);
    } else if (raw['damageResistances'] != null) {
      customProperties['damageResistances'] = raw['damageResistances'].toString();
    }
    if (raw['immune'] != null) {
      customProperties['damageImmunities'] = _formatList(raw['immune']);
    } else if (raw['damageImmunities'] != null) {
      customProperties['damageImmunities'] = raw['damageImmunities'].toString();
    }
    if (raw['conditionImmune'] != null) {
      customProperties['conditionImmunities'] = _formatList(raw['conditionImmune']);
    } else if (raw['conditionImmunities'] != null) {
      customProperties['conditionImmunities'] = raw['conditionImmunities'].toString();
    }
    final senses = raw['senses'] != null ? _formatList(raw['senses']) : '';
    final passive = raw['passive'] != null ? 'passive Perception ${raw['passive']}' : '';
    final sensesStr = [if (senses.isNotEmpty) senses, if (passive.isNotEmpty) passive].join(', ');
    if (sensesStr.isNotEmpty) {
      customProperties['senses'] = sensesStr;
    }
    if (raw['languages'] != null) {
      customProperties['languages'] = _formatList(raw['languages']);
    }

    return Monster(
      id: EntityId(slug: slug, ruleset: ruleset),
      name: name,
      size: size,
      monsterType: typeStr,
      alignment: alignment,
      armorClass: ac,
      hitPoints: hpData.average,
      hitDieFormula: hpData.formula,
      challengeRating: cr,
      actionsMarkdown: actionsBuffer.toString().trim(),
      attackMath: attackMath,
      innateSpells: innateSpells,
      customProperties: customProperties,
    );
  }

  void _appendActionOrTrait(
    dynamic node,
    StringBuffer buffer,
    List<EvaluationMath> attackMath,
    RulesetVersion ruleset, {
    required String defaultTitle,
  }) {
    String aName = defaultTitle;
    ParsedEntryResult? parsed;

    if (node is Map) {
      final rawName = (node['name'] ?? node['title'] ?? defaultTitle).toString();
      aName = transformer.transformEntries(rawName, defaultRuleset: ruleset).markdown;
      final entriesData = node['entries'] ?? node['desc'] ?? node['description'] ?? node['text'] ?? node['entry'];
      parsed = transformer.transformEntries(entriesData, defaultRuleset: ruleset);
    } else if (node is String) {
      final clean = node.trim();
      if (clean.isEmpty) return;
      final splitIdx = clean.indexOf(RegExp(r'[:.]'));
      if (splitIdx != -1 && splitIdx < 35) {
        aName = clean.substring(0, splitIdx).trim();
        final tBody = clean.substring(splitIdx + 1).trim();
        parsed = transformer.transformEntries(tBody, defaultRuleset: ruleset);
      } else {
        parsed = transformer.transformEntries(clean, defaultRuleset: ruleset);
      }
    }

    if (parsed != null) {
      final resolvedMath = parsed.extractedMath.map((m) {
        if (m.damageType != DamageType.untyped) return m;
        final cleanText = parsed!.markdown.toLowerCase();
        final fEsc = RegExp.escape(m.diceFormula.toLowerCase());
        final match = RegExp(
          fEsc + r'[^\n\.]*?\b(acid|bludgeoning|cold|fire|force|lightning|necrotic|piercing|poison|psychic|radiant|slashing|thunder)\s+damage',
          caseSensitive: false,
        ).firstMatch(cleanText);
        if (match != null) {
          final typeStr = match.group(1)!.toLowerCase();
          final resolvedType = DamageType.values.firstWhere(
            (d) => d.name == typeStr,
            orElse: () => DamageType.untyped,
          );
          if (resolvedType != DamageType.untyped) {
            return EvaluationMath(
              diceFormula: m.diceFormula,
              damageType: resolvedType,
              scalingFormula: m.scalingFormula,
            );
          }
        }
        return m;
      }).toList();

      attackMath.addAll(resolvedMath);
      if (aName.isNotEmpty && aName != defaultTitle) {
        buffer.writeln('**$aName**: ${parsed.markdown}\n');
      } else {
        buffer.writeln('${parsed.markdown}\n');
      }
    }
  }

  static const Set<String> _standardMonsterKeys = {
    'name',
    'source',
    'size',
    'type',
    'alignment',
    'ac',
    'hp',
    'cr',
    'speed',
    'trait',
    'traits',
    'action',
    'actions',
    'bonus',
    'bonusActions',
    'reaction',
    'reactions',
    'legendary',
    'legendaryActions',
    'spellcasting',
  };

  String _parseSize(dynamic sizeData) {
    if (sizeData is List && sizeData.isNotEmpty) {
      return _mapSizeCode(sizeData.first.toString());
    } else if (sizeData is String) {
      return _mapSizeCode(sizeData);
    }
    return 'Medium';
  }

  String _mapSizeCode(String code) {
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
      case 'H':
      case 'HUGE':
        return 'Huge';
      case 'G':
      case 'GARGANTUAN':
        return 'Gargantuan';
      default:
        return code;
    }
  }

  String _parseType(dynamic typeData) {
    if (typeData is Map) {
      final t = typeData['type'] ?? 'humanoid';
      final tags = typeData['tags'] as List?;
      if (tags != null && tags.isNotEmpty) {
        return '$t (${tags.join(', ')})';
      }
      return t.toString();
    } else if (typeData is String) {
      return typeData;
    }
    return 'monstrosity';
  }

  String _parseAlignment(dynamic alignData) {
    if (alignData is List) {
      final list = alignData.map((e) => e.toString().toUpperCase().trim()).toList();
      if (list.contains('U') || list.contains('UNALIGNED')) return 'Unaligned';
      if (list.contains('A') || list.contains('ANY')) return 'Any alignment';
      if (list.length == 2 && list[0] == 'N' && list[1] == 'N') return 'Neutral';
      final mapped = list.map((code) => switch (code) {
        'L' => 'Lawful',
        'C' => 'Chaotic',
        'N' => 'Neutral',
        'G' => 'Good',
        'E' => 'Evil',
        _ => code,
      }).join(' ');
      return mapped.isNotEmpty ? mapped : 'Unaligned';
    } else if (alignData is String) {
      return alignData;
    }
    return 'Unaligned';
  }

  int _parseArmorClass(dynamic acData) {
    if (acData is List && acData.isNotEmpty) {
      final first = acData.first;
      if (first is Map) {
        final val = first['ac'] ?? first['value'] ?? first['armourClass'];
        if (val is num) return val.toInt();
        if (val is String) {
          final m = RegExp(r'\d+').firstMatch(val);
          if (m != null) return int.tryParse(m.group(0)!) ?? 10;
        }
        return 10;
      } else if (first is num) {
        return first.toInt();
      } else if (first is String) {
        final m = RegExp(r'\d+').firstMatch(first);
        if (m != null) return int.tryParse(m.group(0)!) ?? 10;
      }
    } else if (acData is Map) {
      final val = acData['ac'] ?? acData['value'] ?? acData['armourClass'];
      if (val is num) return val.toInt();
      if (val is String) {
        final m = RegExp(r'\d+').firstMatch(val);
        if (m != null) return int.tryParse(m.group(0)!) ?? 10;
      }
      return 10;
    } else if (acData is num) {
      return acData.toInt();
    } else if (acData is String) {
      final match = RegExp(r'\d+').firstMatch(acData);
      if (match != null) {
        return int.tryParse(match.group(0)!) ?? 10;
      }
    }
    return 10;
  }

  ({int average, String formula}) _parseHitPoints(dynamic hpData) {
    int avg = 10;
    String form = '2d8 + 2';

    if (hpData is Map) {
      avg = (hpData['average'] as num?)?.toInt() ?? (hpData['special'] != null ? 1 : 10);
      form = hpData['formula']?.toString() ?? '${avg}hp';
    } else if (hpData is num) {
      avg = hpData.toInt();
      form = '${avg}hp';
    } else if (hpData is String) {
      final match = RegExp(r'(\d+)\s*\((.*?)\)').firstMatch(hpData);
      if (match != null) {
        avg = int.tryParse(match.group(1)!) ?? 10;
        form = match.group(2)!;
      } else {
        avg = int.tryParse(hpData) ?? 10;
        form = '${avg}hp';
      }
    }

    return (average: avg, formula: form);
  }

  String _parseChallengeRating(dynamic crData) {
    if (crData is Map) {
      return crData['cr']?.toString() ?? '1';
    } else if (crData != null) {
      return crData.toString();
    }
    return '0';
  }

  String _parseSpeed(dynamic speedData) {
    if (speedData is num) {
      return 'walk ${speedData}ft.';
    }
    if (speedData is Map) {
      final parts = <String>[];
      speedData.forEach((mode, val) {
        if (mode == 'walk' || mode == 'speed') {
          if (val is Map) {
            final numVal = val['number'] ?? val['amount'] ?? 30;
            final cond = val['condition'] != null ? ' (${val['condition']})' : '';
            parts.add('walk ${numVal}ft.$cond'.trim());
          } else {
            parts.add('walk ${val}ft.');
          }
        } else if (val is Map) {
          final cond = val['condition'] != null ? ', (${val['condition']})' : '';
          final numVal = val['number'] ?? val['amount'] ?? '';
          parts.add('$mode ${numVal}ft.$cond'.trim());
        } else if (val == true) {
          if (mode == 'canHover' || mode == 'hover') {
            parts.add('(hover)');
          } else {
            parts.add(mode);
          }
        } else if (val == false) {
          // ignore false flags
        } else {
          parts.add('$mode ${val}ft.');
        }
      });
      return parts.isNotEmpty ? parts.join(', ') : '30 ft.';
    } else if (speedData != null) {
      final str = speedData.toString().trim();
      if (RegExp(r'^\d+$').hasMatch(str)) {
        return 'walk ${str}ft.';
      }
      return str.isNotEmpty ? str : '30 ft.';
    }
    return '30 ft.';
  }

  String _formatAbilityScores(Map<String, dynamic> raw) {
    final str = raw['str'] ?? 10;
    final dex = raw['dex'] ?? 10;
    final con = raw['con'] ?? 10;
    final intScore = raw['int'] ?? 10;
    final wis = raw['wis'] ?? 10;
    final cha = raw['cha'] ?? 10;

    String mod(num score) {
      final m = ((score - 10) / 2).floor();
      return m >= 0 ? '+$m' : '$m';
    }

    return '| STR | DEX | CON | INT | WIS | CHA |\n'
        '|:---:|:---:|:---:|:---:|:---:|:---:|\n'
        '| $str (${mod(str as num)}) | $dex (${mod(dex as num)}) | $con (${mod(con as num)}) | $intScore (${mod(intScore as num)}) | $wis (${mod(wis as num)}) | $cha (${mod(cha as num)}) |';
  }

  void _appendDefensesAndSenses(Map<String, dynamic> raw, StringBuffer buffer) {
    if (raw['save'] is Map) {
      final saves = (raw['save'] as Map).entries.map((e) => '${e.key.toString().toUpperCase()} ${e.value}').join(', ');
      buffer.writeln('**Saving Throws:** $saves');
    }
    if (raw['skill'] is Map) {
      final skills = (raw['skill'] as Map).entries.map((e) => '${e.key} ${e.value}').join(', ');
      buffer.writeln('**Skills:** $skills');
    }
    if (raw['vulnerable'] != null) {
      buffer.writeln('**Damage Vulnerabilities:** ${_formatList(raw['vulnerable'])}');
    }
    if (raw['resist'] != null) {
      buffer.writeln('**Damage Resistances:** ${_formatList(raw['resist'])}');
    }
    if (raw['immune'] != null) {
      buffer.writeln('**Damage Immunities:** ${_formatList(raw['immune'])}');
    }
    if (raw['conditionImmune'] != null) {
      buffer.writeln('**Condition Immunities:** ${_formatList(raw['conditionImmune'])}');
    }
    final senses = raw['senses'] != null ? _formatList(raw['senses']) : '';
    final passive = raw['passive'] != null ? 'passive Perception ${raw['passive']}' : '';
    final sensesStr = [if (senses.isNotEmpty) senses, if (passive.isNotEmpty) passive].join(', ');
    if (sensesStr.isNotEmpty) {
      buffer.writeln('**Senses:** $sensesStr');
    }
    if (raw['languages'] != null) {
      buffer.writeln('**Languages:** ${_formatList(raw['languages'])}');
    }
    buffer.writeln();
  }

  String _formatList(dynamic val) {
    if (val is List) {
      return val.map((e) => e is Map ? (e['note'] != null ? '${e['resist'] ?? e['immune'] ?? ''} (${e['note']})' : e.toString()) : e.toString()).join(', ');
    }
    return val.toString();
  }

  List<String> _extractSpellNames(List list, List<EntityReference<Spell>> innateSpells, RulesetVersion ruleset) {
    final names = <String>[];
    for (final item in list) {
      String rawText = '';
      if (item is String) {
        rawText = item;
      } else if (item is Map) {
        rawText = (item['entry'] ?? item['name'] ?? item['item'] ?? '').toString();
      }
      if (rawText.trim().isEmpty) continue;

      final match = RegExp(r'\{@spell\s+([^|}]+).*?\}').firstMatch(rawText);
      final clean = match != null ? match.group(1)!.trim() : rawText.trim();
      names.add('*$clean*');
      innateSpells.add(EntityReference<Spell>(
        refType: EntityType.spell,
        slug: _slugify(clean),
        displayName: clean,
        rulesetPreferred: ruleset,
      ));
    }
    return names;
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
    if (s.contains('XMM') || s.contains('SRD52') || s.contains('2024')) {
      return RulesetVersion.v2024;
    }
    if (s.contains('MM') || s.contains('SRD') || s.contains('2014')) {
      return RulesetVersion.v2014;
    }
    return RulesetVersion.homebrew;
  }

  /// Pre-resolves `_copy` specifications using a provider of base monster raw maps or the MonsterCodexLibrary.
  Map<String, dynamic> resolveCopy(
    Map<String, dynamic> raw, {
    Map<String, dynamic>? Function(String name, String? source)? baseLookup,
  }) {
    final copy = (raw['_copy'] ?? (raw['customProperties'] is Map ? raw['customProperties']['_copy'] : null)) as Map?;
    if (copy == null) {
      return raw;
    }

    final copyName = copy['name']?.toString().trim();
    if (copyName == null || copyName.isEmpty) return raw;
    final copySource = copy['source']?.toString().trim();

    Map<String, dynamic>? base;
    if (baseLookup != null) {
      base = baseLookup(copyName, copySource);
    }
    if (base == null) {
      final codexMatch = MonsterCodexLibrary.getMonsterByName(copyName);
      if (codexMatch != null) {
        base = _monsterItemToRawMap(codexMatch);
      }
    }

    if (base == null) {
      return raw;
    }

    // Deep copy base map
    final merged = json.decode(json.encode(base)) as Map<String, dynamic>;

    // Apply _mod modifications
    final mod = copy['_mod'];
    if (mod is Map) {
      _applyMod(merged, mod);
    }

    final hasDefaultStats = raw['actionsMarkdown'] != null &&
        (raw['actionsMarkdown'].toString().contains('| 10 (+0) | 10 (+0) | 10 (+0) | 10 (+0) | 10 (+0) | 10 (+0) |') ||
            raw['actionsMarkdown'].toString().startsWith('**Speed:** 30 ft.\n\n| STR | DEX'));

    // Merge overlay fields from raw (except _copy)
    raw.forEach((key, value) {
      if (key != '_copy' && key != 'customProperties') {
        if (hasDefaultStats) {
          if (key == 'str' ||
              key == 'dex' ||
              key == 'con' ||
              key == 'int' ||
              key == 'wis' ||
              key == 'cha' ||
              key == 'strScore' ||
              key == 'dexScore' ||
              key == 'conScore' ||
              key == 'intScore' ||
              key == 'wisScore' ||
              key == 'chaScore') {
            return;
          }
          if (key == 'cr' && (value == '0' || value == 0)) {
            return;
          }
          if (key == 'hp' && (value == 10 || (value is Map && value['average'] == 10))) {
            return;
          }
          if (key == 'ac' && (value == 10 || (value is List && value.contains(10)))) {
            return;
          }
          if (key == 'actionsMarkdown' &&
              (value == null ||
                  value.toString().isEmpty ||
                  value.toString().startsWith('**Speed:** 30 ft.\n\n| STR | DEX'))) {
            return;
          }
        }
        merged[key] = value;
      }
    });

    // Keep _copy in customProperties
    merged['_copy'] = copy;

    return merged;
  }

  void _applyMod(Map<String, dynamic> target, Map mod) {
    mod.forEach((key, modRule) {
      final ruleList = modRule is List ? modRule : [modRule];
      for (final rule in ruleList) {
        if (rule is! Map) continue;
        final mode = rule['mode']?.toString();

        if (key == '*' || mode == 'replaceTxt') {
          final replace = rule['replace']?.toString();
          final withTxt = rule['with']?.toString() ?? '';
          if (replace != null && replace.isNotEmpty) {
            final flags = rule['flags']?.toString() ?? '';
            final caseSensitive = !flags.contains('i');
            _replaceTextInNode(target, replace, withTxt, caseSensitive: caseSensitive);
          }
        } else if (mode == 'appendArr') {
          final items = rule['items'];
          final arr = target[key];
          if (arr is List && items != null) {
            if (items is List) {
              arr.addAll(items);
            } else {
              arr.add(items);
            }
          } else if (items != null) {
            target[key] = items is List ? List.from(items) : [items];
          }
        } else if (mode == 'prependArr') {
          final items = rule['items'];
          final arr = target[key];
          if (arr is List && items != null) {
            if (items is List) {
              arr.insertAll(0, items);
            } else {
              arr.insert(0, items);
            }
          } else if (items != null) {
            target[key] = items is List ? List.from(items) : [items];
          }
        } else if (mode == 'replaceArr') {
          final replace = rule['replace'];
          final withItem = rule['items'] ?? rule['with'];
          final arr = target[key];
          if (arr is List && replace != null && withItem != null) {
            final matchName = (replace is Map ? replace['name']?.toString() : replace.toString())?.toLowerCase().trim();
            final idx = arr.indexWhere((it) =>
                it is Map && ((it['name']?.toString() ?? it['title']?.toString())?.toLowerCase().trim() == matchName));
            if (idx != -1) {
              if (withItem is List) {
                arr.removeAt(idx);
                arr.insertAll(idx, withItem);
              } else {
                arr[idx] = withItem;
              }
            }
          }
        } else if (mode == 'removeArr') {
          final names = rule['names'];
          final arr = target[key];
          if (arr is List && names != null) {
            final nameList = names is List
                ? names.map((e) => e.toString().toLowerCase()).toSet()
                : {names.toString().toLowerCase()};
            arr.removeWhere((it) =>
                it is Map && nameList.contains((it['name'] ?? it['title'])?.toString().toLowerCase()));
          }
        } else if (mode == 'addSkills' || mode == 'skills') {
          final skills = rule['skills'];
          if (skills is Map) {
            final current = target['skill'] is Map ? Map<String, dynamic>.from(target['skill'] as Map) : <String, dynamic>{};
            skills.forEach((k, v) => current[k.toString()] = v);
            target['skill'] = current;
          }
        }
      }
    });
  }

  void _replaceTextInNode(dynamic node, String search, String replace, {bool caseSensitive = true}) {
    if (node is Map) {
      for (final key in node.keys.toList()) {
        final val = node[key];
        if (val is String) {
          node[key] = val.replaceAll(
            RegExp(RegExp.escape(search), caseSensitive: caseSensitive),
            replace,
          );
        } else {
          _replaceTextInNode(val, search, replace, caseSensitive: caseSensitive);
        }
      }
    } else if (node is List) {
      for (int i = 0; i < node.length; i++) {
        final val = node[i];
        if (val is String) {
          node[i] = val.replaceAll(
            RegExp(RegExp.escape(search), caseSensitive: caseSensitive),
            replace,
          );
        } else {
          _replaceTextInNode(val, search, replace, caseSensitive: caseSensitive);
        }
      }
    }
  }

  static Map<String, dynamic> _monsterItemToRawMap(MonsterItem item) {
    final sb = item.sourceStatBlock;
    return {
      'name': item.name,
      'size': [sb.sizeDisplay],
      'type': sb.typeDisplay,
      'alignment': [sb.alignment],
      'ac': [sb.ac],
      'hp': {'average': sb.maxHp, 'formula': sb.hitDice ?? '${sb.maxHp}hp'},
      'speed': sb.speed,
      'str': sb.strScore,
      'dex': sb.dexScore,
      'con': sb.conScore,
      'int': sb.intScore,
      'wis': sb.wisScore,
      'cha': sb.chaScore,
      'cr': item.sourceStatBlock.crDisplay.replaceAll(RegExp(r'^CR\s*', caseSensitive: false), '').trim(),
      'trait': sb.traits.map((t) => {'name': t.name, 'entries': [t.description]}).toList(),
      'action': sb.actions.map((a) => {
        'name': a.name,
        'entries': [a.description],
      }).toList(),
      'reaction': sb.reactions.map((r) => {'name': r.name, 'entries': [r.description]}).toList(),
      'senses': sb.senses,
      'languages': sb.languages,
      'savingThrows': sb.savingThrows,
      'skills': sb.skills,
      'immune': sb.damageImmunities,
      'resist': sb.damageResistances,
      'vulnerable': sb.damageVulnerabilities,
      'conditionImmune': sb.conditionImmunities,
    };
  }
}

