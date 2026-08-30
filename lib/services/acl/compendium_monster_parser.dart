import '../../models/domain/core_types.dart';
import '../../models/domain/entity_reference.dart';
import '../../models/domain/spell_monster_equipment.dart';
import 'entry_tag_transformer.dart';

/// Anti-Corruption Layer (ACL) dedicated transformer for Community Compendium and Homebrew Monsters/NPCs.
class CompendiumMonsterParser {
  final EntryTagTransformer transformer;

  CompendiumMonsterParser({EntryTagTransformer? transformer})
      : transformer = transformer ?? EntryTagTransformer();

  /// Transforms a raw community compendium or homebrew monster JSON map into a strongly-typed [Monster].
  Monster parseMonster(Map<String, dynamic> raw, {RulesetVersion? forceRuleset}) {
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
        if (trait is Map) {
          final tName = trait['name'] ?? 'Trait';
          final parsed = transformer.transformEntries(trait['entries'], defaultRuleset: ruleset);
          attackMath.addAll(parsed.extractedMath);
          actionsBuffer.writeln('**$tName**: ${parsed.markdown}\n');
        }
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
                actionsBuffer.writeln('- **$freq/day each:** ${spellNames.join(', ')}');
              }
            });
          }
          final spellsObj = sc['spells'] as Map?;
          if (spellsObj != null) {
            spellsObj.forEach((lvl, data) {
              if (data is Map && data['spells'] is List) {
                final spellNames = _extractSpellNames(data['spells'] as List, innateSpells, ruleset);
                final slots = data['slots'] != null ? ' (${data['slots']} slots)' : '';
                actionsBuffer.writeln('- **Level $lvl$slots:** ${spellNames.join(', ')}');
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
        if (action is Map) {
          final aName = action['name'] ?? 'Action';
          final parsed = transformer.transformEntries(action['entries'], defaultRuleset: ruleset);
          attackMath.addAll(parsed.extractedMath);
          actionsBuffer.writeln('**$aName**: ${parsed.markdown}\n');
        }
      }
    }

    // Bonus Actions
    final bonus = (raw['bonus'] is List ? raw['bonus'] : raw['bonusActions']) as List?;
    if (bonus != null && bonus.isNotEmpty) {
      actionsBuffer.writeln('### Bonus Actions');
      for (final b in bonus) {
        if (b is Map) {
          final bName = b['name'] ?? 'Bonus Action';
          final parsed = transformer.transformEntries(b['entries'], defaultRuleset: ruleset);
          attackMath.addAll(parsed.extractedMath);
          actionsBuffer.writeln('**$bName**: ${parsed.markdown}\n');
        }
      }
    }

    // Reactions
    final reactions = (raw['reaction'] is List ? raw['reaction'] : raw['reactions']) as List?;
    if (reactions != null && reactions.isNotEmpty) {
      actionsBuffer.writeln('### Reactions');
      for (final r in reactions) {
        if (r is Map) {
          final rName = r['name'] ?? 'Reaction';
          final parsed = transformer.transformEntries(r['entries'], defaultRuleset: ruleset);
          attackMath.addAll(parsed.extractedMath);
          actionsBuffer.writeln('**$rName**: ${parsed.markdown}\n');
        }
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
        actionsBuffer.writeln('The monster can take $count legendary actions, choosing from the options below.\n');
      }
      for (final leg in legendary) {
        if (leg is Map) {
          final lName = leg['name'] ?? 'Option';
          final parsed = transformer.transformEntries(leg['entries'], defaultRuleset: ruleset);
          attackMath.addAll(parsed.extractedMath);
          actionsBuffer.writeln('**$lName**: ${parsed.markdown}\n');
        }
      }
    }

    // Mythic Actions
    final mythic = (raw['mythic'] is List ? raw['mythic'] : raw['mythicActions']) as List?;
    if (mythic != null && mythic.isNotEmpty) {
      actionsBuffer.writeln('### Mythic Actions');
      final mythicHeader = raw['mythicHeader'] as List?;
      if (mythicHeader != null) {
        final parsedHeader = transformer.transformEntries(mythicHeader, defaultRuleset: ruleset);
        actionsBuffer.writeln('${parsedHeader.markdown}\n');
      }
      for (final m in mythic) {
        if (m is Map) {
          final mName = m['name'] ?? 'Mythic Option';
          final parsed = transformer.transformEntries(m['entries'], defaultRuleset: ruleset);
          attackMath.addAll(parsed.extractedMath);
          actionsBuffer.writeln('**$mName**: ${parsed.markdown}\n');
        }
      }
    }

    // Auxiliary Properties (0% data loss)
    final customProperties = <String, dynamic>{};
    raw.forEach((key, value) {
      if (!_standardMonsterKeys.contains(key)) {
        customProperties[key] = value;
      }
    });

    // Store explicit structured stats in customProperties
    customProperties['str'] = raw['str'] ?? 10;
    customProperties['dex'] = raw['dex'] ?? 10;
    customProperties['con'] = raw['con'] ?? 10;
    customProperties['int'] = raw['int'] ?? 10;
    customProperties['wis'] = raw['wis'] ?? 10;
    customProperties['cha'] = raw['cha'] ?? 10;
    if (raw.containsKey('save')) customProperties['save'] = raw['save'];
    if (raw.containsKey('skill')) customProperties['skill'] = raw['skill'];
    if (raw.containsKey('senses')) customProperties['senses'] = raw['senses'];
    if (raw.containsKey('passive')) customProperties['passive'] = raw['passive'];
    if (raw.containsKey('languages')) customProperties['languages'] = raw['languages'];
    if (raw.containsKey('immune')) customProperties['immune'] = raw['immune'];
    if (raw.containsKey('resist')) customProperties['resist'] = raw['resist'];
    if (raw.containsKey('vulnerable')) customProperties['vulnerable'] = raw['vulnerable'];
    if (raw.containsKey('conditionImmune')) customProperties['conditionImmune'] = raw['conditionImmune'];
    if (raw.containsKey('spellcasting')) customProperties['spellcasting'] = raw['spellcasting'];

    return Monster(
      id: EntityId(slug: slug, ruleset: ruleset),
      name: name,
      size: size,
      monsterType: typeStr,
      alignment: alignment,
      armorClass: ac,
      hitPoints: hpData.hp,
      hitDieFormula: hpData.formula,
      challengeRating: cr,
      actionsMarkdown: actionsBuffer.toString().trim(),
      innateSpells: innateSpells,
      attackMath: attackMath,
      customProperties: customProperties,
    );
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
    'legendaryHeader',
    'mythic',
    'mythicActions',
    'mythicHeader',
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

  String _parseType(dynamic typeData) {
    if (typeData is String) return typeData;
    if (typeData is Map) {
      final base = typeData['type']?.toString() ?? 'Humanoid';
      final tags = (typeData['tags'] as List?)?.map((e) => e.toString()).toList();
      if (tags != null && tags.isNotEmpty) {
        return '$base (${tags.join(', ')})';
      }
      return base;
    }
    return 'Humanoid';
  }

  String _parseAlignment(dynamic alignData) {
    if (alignData is List) {
      final parts = alignData.map((e) {
        switch (e.toString().toUpperCase()) {
          case 'L':
            return 'Lawful';
          case 'C':
            return 'Chaotic';
          case 'N':
            return 'Neutral';
          case 'G':
            return 'Good';
          case 'E':
            return 'Evil';
          case 'U':
            return 'Unaligned';
          case 'A':
            return 'Any Alignment';
          default:
            return e.toString();
        }
      }).toList();
      return parts.join(' ');
    } else if (alignData != null) {
      return alignData.toString();
    }
    return 'unaligned';
  }

  int _parseArmorClass(dynamic acData) {
    if (acData is num) return acData.toInt();
    if (acData is List && acData.isNotEmpty) {
      final first = acData.first;
      if (first is num) return first.toInt();
      if (first is Map) return (first['ac'] as num?)?.toInt() ?? 10;
      if (first is String) return int.tryParse(first) ?? 10;
    } else if (acData is Map) {
      return (acData['ac'] as num?)?.toInt() ?? 10;
    }
    return 10;
  }

  ({int hp, String formula}) _parseHitPoints(dynamic hpData) {
    if (hpData is num) {
      return (hp: hpData.toInt(), formula: '${hpData}d8');
    }
    if (hpData is Map) {
      final avg = (hpData['average'] as num?)?.toInt() ?? 10;
      final formula = hpData['formula']?.toString() ?? '${avg}d8';
      return (hp: avg, formula: formula);
    }
    return (hp: 10, formula: '2d8');
  }

  String _parseChallengeRating(dynamic crData) {
    if (crData is String) return crData;
    if (crData is num) return crData.toString();
    if (crData is Map) {
      return crData['cr']?.toString() ?? '1';
    }
    return '1';
  }

  String _parseSpeed(dynamic speedData) {
    if (speedData is String) return speedData;
    if (speedData is Map) {
      final parts = <String>[];
      speedData.forEach((k, v) {
        if (v is bool && v == true && k == 'canHover') {
          parts.add('(hover)');
        } else if (v is num) {
          parts.add('$k ${v}ft.');
        } else if (v is Map) {
          final amt = v['number'] ?? 30;
          parts.add('$k ${amt}ft.');
        }
      });
      return parts.join(', ');
    }
    return '30 ft.';
  }

  String _formatAbilityScores(Map<String, dynamic> raw) {
    int str = (raw['str'] as num?)?.toInt() ?? 10;
    int dex = (raw['dex'] as num?)?.toInt() ?? 10;
    int con = (raw['con'] as num?)?.toInt() ?? 10;
    int intl = (raw['int'] as num?)?.toInt() ?? 10;
    int wis = (raw['wis'] as num?)?.toInt() ?? 10;
    int cha = (raw['cha'] as num?)?.toInt() ?? 10;

    String modStr(int val) {
      final mod = ((val - 10) / 2).floor();
      return mod >= 0 ? '+$mod' : '$mod';
    }

    return '| STR | DEX | CON | INT | WIS | CHA |\n'
        '|:---:|:---:|:---:|:---:|:---:|:---:|\n'
        '| $str (${modStr(str)}) | $dex (${modStr(dex)}) | $con (${modStr(con)}) | $intl (${modStr(intl)}) | $wis (${modStr(wis)}) | $cha (${modStr(cha)}) |';
  }

  void _appendDefensesAndSenses(Map<String, dynamic> raw, StringBuffer buffer) {
    if (raw.containsKey('save') && raw['save'] is Map) {
      final saves = (raw['save'] as Map).entries.map((e) => '${e.key.toString().toUpperCase()} ${e.value}').join(', ');
      buffer.writeln('**Saving Throws:** $saves');
    }
    if (raw.containsKey('skill') && raw['skill'] is Map) {
      final skills = (raw['skill'] as Map).entries.map((e) => '${e.key} ${e.value}').join(', ');
      buffer.writeln('**Skills:** $skills');
    }
    if (raw.containsKey('vulnerable')) {
      buffer.writeln('**Damage Vulnerabilities:** ${_formatListOrString(raw['vulnerable'])}');
    }
    if (raw.containsKey('resist')) {
      buffer.writeln('**Damage Resistances:** ${_formatListOrString(raw['resist'])}');
    }
    if (raw.containsKey('immune')) {
      buffer.writeln('**Damage Immunities:** ${_formatListOrString(raw['immune'])}');
    }
    if (raw.containsKey('conditionImmune')) {
      buffer.writeln('**Condition Immunities:** ${_formatListOrString(raw['conditionImmune'])}');
    }
    if (raw.containsKey('senses')) {
      buffer.writeln('**Senses:** ${_formatListOrString(raw['senses'])}${raw['passive'] != null ? ', passive Perception ${raw['passive']}' : ''}');
    }
    if (raw.containsKey('languages')) {
      buffer.writeln('**Languages:** ${_formatListOrString(raw['languages'])}\n');
    }
  }

  String _formatListOrString(dynamic val) {
    if (val is List) {
      return val.map((e) {
        if (e is Map) return e.toString();
        return e.toString();
      }).join(', ');
    }
    return val?.toString() ?? '';
  }

  List<String> _extractSpellNames(
    List list,
    List<EntityReference<Spell>> innateSpells,
    RulesetVersion ruleset,
  ) {
    final names = <String>[];
    for (final item in list) {
      final str = item.toString();
      // Look for {@spell name}
      final match = RegExp(r'\{@spell\s+([^|}]+)').firstMatch(str);
      final spellName = match != null ? match.group(1)! : str.replaceAll(RegExp(r'\{@[a-z]+\s+|[\}]'), '');
      names.add(spellName);
      innateSpells.add(EntityReference<Spell>(
        refType: EntityType.spell,
        slug: _slugify(spellName),
        displayName: spellName,
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
    if (s.contains('XPHB') || s.contains('SRD52') || s.contains('2024')) {
      return RulesetVersion.v2024;
    }
    if (s.contains('PHB') || s.contains('SRD') || s.contains('2014')) {
      return RulesetVersion.v2014;
    }
    return RulesetVersion.homebrew;
  }
}
