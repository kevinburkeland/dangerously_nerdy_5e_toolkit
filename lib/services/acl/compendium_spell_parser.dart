import '../../models/domain/core_types.dart';
import '../../models/domain/spell_monster_equipment.dart';
import '../../models/spellbook_data.dart';
import 'entry_tag_transformer.dart';

/// Anti-Corruption Layer (ACL) dedicated transformer for Community Compendium and Homebrew Spells.
class CompendiumSpellParser {
  final EntryTagTransformer transformer;

  CompendiumSpellParser({EntryTagTransformer? transformer})
      : transformer = transformer ?? EntryTagTransformer();

  /// Transforms a raw community compendium or homebrew spell JSON map into a strongly-typed [Spell].
  Spell parseSpell(Map<String, dynamic> raw, {RulesetVersion? forceRuleset}) {
    final name = raw['name']?.toString().trim() ?? 'Unnamed Spell';
    final slug = _slugify(name);
    final level = (raw['level'] as num?)?.toInt() ?? 0;
    final source = raw['source']?.toString().toUpperCase() ?? 'PHB';

    final ruleset = forceRuleset ?? _mapSourceToRuleset(source);

    // School mapping (1-letter abbreviation or full name)
    final rawSchool = raw['school']?.toString().toUpperCase() ?? 'V';
    final school = _mapSchool(rawSchool);

    // Casting Time
    final castingTime = _parseCastingTime(raw['time'] ?? raw['castingTime']);

    // Duration
    final duration = _parseDuration(raw['duration']);

    // Range
    final rangeStr = _parseRange(raw['range']);

    // Components
    final components = _parseComponents(raw['components'] ?? raw['component']);

    // Markdown description entries (support entries, desc, description, text)
    final entriesData = raw['entries'] ?? raw['desc'] ?? raw['description'] ?? raw['text'];
    final transformed = transformer.transformEntries(
      entriesData,
      defaultRuleset: ruleset,
    );

    // Higher level entries
    String? higherLevelsMarkdown;
    final hlData = raw['entriesHigherLevel'] ?? raw['higherLevel'] ?? raw['higherLevels'];
    if (hlData != null) {
      final hl = transformer.transformEntries(
        hlData,
        defaultRuleset: ruleset,
      );
      if (hl.markdown.isNotEmpty) {
        higherLevelsMarkdown = hl.markdown;
      }
    }

    // Damage Math & Evaluation
    var damageMath = List<EvaluationMath>.from(transformed.extractedMath);
    if (damageMath.isEmpty && raw['damageInflict'] is List) {
      for (final dmg in raw['damageInflict']) {
        final dmgType = DamageType.fromLooseString(dmg?.toString());
        if (dmgType != DamageType.untyped) {
          damageMath.add(EvaluationMath(
            diceFormula: '1d6',
            damageType: dmgType,
          ));
        }
      }
    }

    // Infer damage type if damageMath has untyped damage
    if (damageMath.isNotEmpty) {
      DamageType? inferred;
      if (raw['damageInflict'] is List && (raw['damageInflict'] as List).isNotEmpty) {
        inferred = DamageType.fromLooseString((raw['damageInflict'] as List).first?.toString());
      }
      if (inferred == null || inferred == DamageType.untyped) {
        final descLower = transformed.markdown.toLowerCase();
        for (final dt in DamageType.values) {
          if (dt != DamageType.untyped && descLower.contains('${dt.name} damage')) {
            inferred = dt;
            break;
          }
        }
      }
      if (inferred != null && inferred != DamageType.untyped) {
        damageMath = damageMath.map((m) {
          if (m.damageType == DamageType.untyped) {
            return EvaluationMath(
              diceFormula: m.diceFormula,
              damageType: inferred!,
              scalingFormula: m.scalingFormula,
            );
          }
          return m;
        }).toList();
      }
    }

    // Scaling level dice
    if (raw['scalingLevelDice'] is Map) {
      final sld = raw['scalingLevelDice'] as Map;
      final scaling = sld['scaling'];
      if (scaling is Map && scaling.isNotEmpty) {
        final firstScale = scaling.values.first?.toString();
        if (firstScale != null && damageMath.isNotEmpty) {
          damageMath = [
            EvaluationMath(
              diceFormula: damageMath.first.diceFormula,
              damageType: damageMath.first.damageType,
              scalingFormula: '+$firstScale per higher slot',
            ),
            ...damageMath.skip(1),
          ];
        }
      }
    }

    // Capture all auxiliary & unmapped fields in customProperties to guarantee 0% data loss
    final customProperties = <String, dynamic>{};
    raw.forEach((key, value) {
      if (!_standardSpellKeys.contains(key)) {
        customProperties[key] = value;
      }
    });

    // Preserve raw classes if present as Map (ensuring 0% data loss); if omitted or empty, attempt SRD / expansion index inheritance
    final rawClasses = raw['classes'] ?? customProperties['classes'];
    if (rawClasses is Map && rawClasses.isNotEmpty) {
      customProperties['classes'] = rawClasses;
      final hasClassList = (rawClasses['fromClassList'] is List && (rawClasses['fromClassList'] as List).isNotEmpty);
      final hasSubclass = (rawClasses['fromSubclass'] is List && (rawClasses['fromSubclass'] as List).isNotEmpty);
      if (!hasClassList && !hasSubclass) {
        final parsed = _extractClasses(rawClasses, slug, name, ruleset);
        if (parsed.isNotEmpty) {
          rawClasses['fromClassList'] = parsed.map((c) => {'name': c, 'source': 'PHB'}).toList();
        }
      }
    } else {
      final parsedClasses = _extractClasses(rawClasses, slug, name, ruleset);
      if (parsedClasses.isNotEmpty) {
        customProperties['classes'] = parsedClasses;
      }
    }
    if (raw.containsKey('page')) {
      customProperties['page'] = raw['page'];
    }
    if (raw.containsKey('savingThrow')) {
      customProperties['savingThrow'] = raw['savingThrow'];
    }
    if (raw.containsKey('spellAttack')) {
      customProperties['spellAttack'] = raw['spellAttack'];
    }
    if (raw.containsKey('areaTags')) {
      customProperties['areaTags'] = raw['areaTags'];
    }
    if (raw.containsKey('miscTags')) {
      customProperties['miscTags'] = raw['miscTags'];
    }

    return Spell(
      id: EntityId(slug: slug, ruleset: ruleset),
      name: name,
      level: level,
      school: school,
      castingTime: castingTime,
      duration: duration,
      range: rangeStr,
      components: components,
      descriptionMarkdown: transformed.markdown,
      higherLevelsMarkdown: higherLevelsMarkdown,
      damageMath: damageMath,
      relatedEntityRefs: transformed.extractedRefs,
      customProperties: customProperties,
    );
  }

  static const Set<String> _standardSpellKeys = {
    'name',
    'source',
    'level',
    'school',
    'time',
    'castingTime',
    'duration',
    'range',
    'components',
    'component',
    'entries',
    'desc',
    'description',
    'text',
    'entriesHigherLevel',
    'higherLevel',
    'higherLevels',
    'damageInflict',
  };

  CastingTime _parseCastingTime(dynamic timeData) {
    int cost = 1;
    ActionType actionType = ActionType.action;
    String? triggerCondition;

    if (timeData is List && timeData.isNotEmpty) {
      final first = timeData.first;
      if (first is Map) {
        cost = (first['number'] as num?)?.toInt() ?? 1;
        final unit = first['unit']?.toString().toLowerCase() ?? 'action';
        actionType = _mapActionType(unit);
        triggerCondition = first['condition']?.toString();
      } else if (first is String) {
        return _parseCastingTimeString(first);
      }
    } else if (timeData is Map) {
      cost = (timeData['number'] as num?)?.toInt() ?? 1;
      final unit = timeData['unit']?.toString().toLowerCase() ?? 'action';
      actionType = _mapActionType(unit);
      triggerCondition = timeData['condition']?.toString();
    } else if (timeData is String) {
      return _parseCastingTimeString(timeData);
    }

    return CastingTime(
      cost: cost,
      actionType: actionType,
      triggerCondition: triggerCondition,
    );
  }

  CastingTime _parseCastingTimeString(String str) {
    final lower = str.toLowerCase().trim();
    if (lower.contains('bonus')) {
      return const CastingTime(cost: 1, actionType: ActionType.bonusAction);
    }
    if (lower.contains('reaction')) {
      return const CastingTime(cost: 1, actionType: ActionType.reaction);
    }
    if (lower.contains('minute')) {
      final match = RegExp(r'\d+').firstMatch(lower);
      final mins = match != null ? (int.tryParse(match.group(0)!) ?? 1) : 1;
      return CastingTime(cost: mins, actionType: ActionType.minute);
    }
    if (lower.contains('hour')) {
      final match = RegExp(r'\d+').firstMatch(lower);
      final hrs = match != null ? (int.tryParse(match.group(0)!) ?? 1) : 1;
      return CastingTime(cost: hrs, actionType: ActionType.hour);
    }
    return const CastingTime(cost: 1, actionType: ActionType.action);
  }

  ActionType _mapActionType(String unit) {
    switch (unit.toLowerCase().trim()) {
      case 'bonus':
      case 'bonus action':
        return ActionType.bonusAction;
      case 'reaction':
        return ActionType.reaction;
      case 'minute':
      case 'minutes':
        return ActionType.minute;
      case 'hour':
      case 'hours':
        return ActionType.hour;
      default:
        return ActionType.action;
    }
  }

  SpellDuration _parseDuration(dynamic durationData) {
    if (durationData is List && durationData.isNotEmpty) {
      final first = durationData.first;
      if (first is Map) {
        final typeStr = first['type']?.toString().toLowerCase() ?? 'instant';
        final concentration = first['concentration'] == true;
        final durationObj = first['duration'] as Map?;

        if (typeStr == 'instant' || typeStr == 'instantaneous') {
          return const SpellDuration(type: DurationType.instantaneous);
        }
        if (typeStr == 'timed' && durationObj != null) {
          final amount = (durationObj['amount'] as num?)?.toInt() ?? 1;
          final unit = durationObj['type']?.toString().toLowerCase() ?? 'round';
          int seconds = amount;
          if (unit.contains('round')) seconds = amount * 6;
          if (unit.contains('minute')) seconds = amount * 60;
          if (unit.contains('hour')) seconds = amount * 3600;
          if (unit.contains('day')) seconds = amount * 86400;

          return SpellDuration(
            type: DurationType.timed,
            durationSeconds: seconds,
            requiresConcentration: concentration,
            rawText: '$amount $unit',
          );
        }
        if (typeStr == 'permanent') {
          return const SpellDuration(type: DurationType.permanent);
        }
        if (typeStr == 'special') {
          return const SpellDuration(type: DurationType.special);
        }
      } else if (first is String) {
        return _parseDurationString(first);
      }
    } else if (durationData is String) {
      return _parseDurationString(durationData);
    }

    return const SpellDuration(type: DurationType.instantaneous);
  }

  SpellDuration _parseDurationString(String str) {
    final lower = str.toLowerCase().trim();
    final isConcentration = lower.contains('concentration');

    if (lower.contains('instant')) {
      return const SpellDuration(type: DurationType.instantaneous);
    }
    if (lower.contains('permanent')) {
      return const SpellDuration(type: DurationType.permanent);
    }
    if (lower.contains('special')) {
      return const SpellDuration(type: DurationType.special);
    }

    final match = RegExp(r'(\d+)\s*(round|minute|hour|day)s?').firstMatch(lower);
    if (match != null) {
      final amount = int.tryParse(match.group(1)!) ?? 1;
      final unit = match.group(2)!;
      int seconds = amount;
      if (unit.contains('round')) seconds = amount * 6;
      if (unit.contains('minute')) seconds = amount * 60;
      if (unit.contains('hour')) seconds = amount * 3600;
      if (unit.contains('day')) seconds = amount * 86400;

      return SpellDuration(
        type: DurationType.timed,
        durationSeconds: seconds,
        requiresConcentration: isConcentration,
        rawText: '$amount $unit',
      );
    }

    return SpellDuration(
      type: DurationType.timed,
      requiresConcentration: isConcentration,
      rawText: str,
    );
  }

  String _parseRange(dynamic rangeData) {
    if (rangeData is Map) {
      final type = rangeData['type']?.toString().toLowerCase() ?? 'point';
      final distance = rangeData['distance'] as Map?;
      if (distance != null) {
        final amount = distance['amount'] ?? '';
        final unit = distance['type']?.toString() ?? 'feet';
        if (type == 'point') {
          return '$amount $unit'.trim();
        }
        return '$type ($amount $unit)'.trim();
      }
      return type;
    } else if (rangeData is String) {
      return rangeData;
    }
    return 'Self';
  }

  SpellComponents _parseComponents(dynamic compData) {
    bool v = false;
    bool s = false;
    bool m = false;
    String? matDesc;
    int cost = 0;
    bool consumed = false;

    if (compData is Map) {
      v = compData['v'] == true;
      s = compData['s'] == true;
      final rawM = compData['m'];
      if (rawM is String) {
        m = true;
        matDesc = rawM.trim();
      } else if (rawM is Map) {
        m = true;
        matDesc = rawM['text']?.toString().trim();
        final rawCost = rawM['cost'] is num
            ? (rawM['cost'] as num)
            : (rawM['cost'] is String ? num.tryParse(rawM['cost'].toString()) : null);
        cost = rawCost != null
            ? (rawCost >= 100 ? (rawCost / 100).round() : rawCost.toInt())
            : 0;
        consumed = rawM['consume'] == true || rawM['consumed'] == true;
      } else if (rawM == true) {
        m = true;
        matDesc = 'Material components';
      }
    } else if (compData is List) {
      for (final item in compData) {
        final str = item.toString().toUpperCase().trim();
        if (str.startsWith('V')) v = true;
        if (str.startsWith('S')) s = true;
        if (str.startsWith('M')) {
          m = true;
          final match = RegExp(r'M\s*\((.*?)\)', caseSensitive: false).firstMatch(item.toString());
          matDesc = match != null ? match.group(1)!.trim() : item.toString();
        }
      }
    } else if (compData is String) {
      final upper = compData.toUpperCase();
      if (upper.contains('V')) v = true;
      if (upper.contains('S')) s = true;
      if (upper.contains('M')) {
        m = true;
        final match = RegExp(r'M\s*\((.*?)\)', caseSensitive: false).firstMatch(compData);
        matDesc = match != null ? match.group(1)!.trim() : compData;
      }
    }

    return SpellComponents(
      v: v,
      s: s,
      m: m,
      materialDescription: matDesc,
      materialCostGp: cost,
      consumesMaterial: consumed,
    );
  }

  String _mapSchool(String rawSchool) {
    switch (rawSchool.toUpperCase().trim()) {
      case 'A':
      case 'ABJURATION':
        return 'Abjuration';
      case 'C':
      case 'CONJURATION':
        return 'Conjuration';
      case 'D':
      case 'DIVINATION':
        return 'Divination';
      case 'E':
      case 'ENCHANTMENT':
        return 'Enchantment';
      case 'V':
      case 'EVOCATION':
        return 'Evocation';
      case 'I':
      case 'ILLUSION':
        return 'Illusion';
      case 'N':
      case 'NECROMANCY':
        return 'Necromancy';
      case 'T':
      case 'TRANSMUTATION':
        return 'Transmutation';
      default:
        return rawSchool.isNotEmpty ? rawSchool : 'Universal';
    }
  }

  String _slugify(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r"['’]"), '')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }

  List<String> _extractClasses(dynamic rawClasses, String slug, String name, RulesetVersion ruleset) {
    final classes = <String>[];

    if (rawClasses is Map) {
      final fromClassList = rawClasses['fromClassList'];
      if (fromClassList is List) {
        for (final item in fromClassList) {
          if (item is Map && item['name'] != null) {
            final cName = item['name'].toString().trim();
            if (cName.isNotEmpty && !classes.contains(cName)) classes.add(cName);
          } else if (item is String) {
            final cName = item.split('|').first.trim();
            if (cName.isNotEmpty && !classes.contains(cName)) classes.add(cName);
          }
        }
      }
    } else if (rawClasses is List) {
      for (final item in rawClasses) {
        if (item is Map && item['name'] != null) {
          final cName = item['name'].toString().trim();
          if (cName.isNotEmpty && !classes.contains(cName)) classes.add(cName);
        } else if (item != null) {
          final cName = item.toString().split('|').first.trim();
          if (cName.isNotEmpty && !classes.contains(cName)) classes.add(cName);
        }
      }
    } else if (rawClasses is String && rawClasses.isNotEmpty) {
      for (final part in rawClasses.split(',')) {
        final cName = part.split('|').first.trim();
        if (cName.isNotEmpty && !classes.contains(cName)) classes.add(cName);
      }
    }

    // Fallback 1: SRD Match
    if (classes.isEmpty) {
      final srdMatch = SpellbookLibrary.allSpells.where((s) => s.name.toLowerCase() == name.toLowerCase() || s.id == slug).firstOrNull;
      if (srdMatch != null) {
        final srdClasses = (ruleset == RulesetVersion.v2024 ? srdMatch.rules2024 : srdMatch.rules2014).classes;
        for (final sc in srdClasses) {
          if (!classes.contains(sc.label)) classes.add(sc.label);
        }
      }
    }

    // Fallback 2: Known Expansion Spells Index
    if (classes.isEmpty) {
      final slugParts = slug.split('-');
      final normSlug = slugParts.length > 1 ? slugParts.sublist(1).join('-') : slug;
      final nameSlug = _slugify(name);
      final nameParts = nameSlug.split('-');
      final normName = nameParts.length > 1 ? nameParts.sublist(1).join('-') : nameSlug;
      final expansionMatch = _expansionSpellClasses[slug] ??
          _expansionSpellClasses[normSlug] ??
          _expansionSpellClasses[nameSlug] ??
          _expansionSpellClasses[normName];
      if (expansionMatch != null) {
        classes.addAll(expansionMatch);
      }
    }

    return classes;
  }

  static const Map<String, List<String>> _expansionSpellClasses = {
    'blade-of-disaster': ['Sorcerer', 'Warlock', 'Wizard'],
    'booming-blade': ['Artificer', 'Sorcerer', 'Warlock', 'Wizard'],
    'green-flame-blade': ['Artificer', 'Sorcerer', 'Warlock', 'Wizard'],
    'lightning-lure': ['Artificer', 'Sorcerer', 'Warlock', 'Wizard'],
    'sword-burst': ['Artificer', 'Sorcerer', 'Warlock', 'Wizard'],
    'mind-sliver': ['Sorcerer', 'Warlock', 'Wizard'],
    'caustic-brew': ['Artificer', 'Sorcerer', 'Wizard'],
    'mind-whip': ['Sorcerer', 'Wizard'],
    'otherworldly-guise': ['Sorcerer', 'Warlock', 'Wizard'],
    'intellect-fortress': ['Artificer', 'Bard', 'Sorcerer', 'Warlock', 'Wizard'],
    'spirit-shroud': ['Cleric', 'Paladin', 'Warlock', 'Wizard'],
    'summon-aberration': ['Sorcerer', 'Warlock', 'Wizard'],
    'summon-beast': ['Druid', 'Ranger'],
    'summon-celestial': ['Cleric', 'Paladin'],
    'summon-construct': ['Artificer', 'Wizard'],
    'summon-elemental': ['Druid', 'Ranger', 'Wizard'],
    'summon-fey': ['Bard', 'Druid', 'Ranger', 'Warlock', 'Wizard'],
    'summon-fiend': ['Warlock', 'Wizard'],
    'summon-shadowspawn': ['Warlock', 'Wizard'],
    'summon-undead': ['Warlock', 'Wizard'],
    'dream-of-the-blue-veil': ['Bard', 'Sorcerer', 'Warlock', 'Wizard'],
    'frost-fingers': ['Wizard'],
    'silvery-barbs': ['Bard', 'Sorcerer', 'Wizard'],
    'kinetic-jaunt': ['Artificer', 'Bard', 'Sorcerer', 'Wizard'],
    'vortex-warp': ['Artificer', 'Sorcerer', 'Wizard'],
    'wither-and-bloom': ['Druid', 'Sorcerer', 'Wizard'],
    'borrowed-knowledge': ['Bard', 'Cleric', 'Warlock', 'Wizard'],
    'chaos-bolt': ['Sorcerer'],
    'toll-the-dead': ['Cleric', 'Warlock', 'Wizard'],
    'word-of-radiance': ['Cleric'],
    'primal-savagery': ['Druid'],
    'infestation': ['Druid', 'Sorcerer', 'Warlock', 'Wizard'],
    'create-bonfire': ['Artificer', 'Druid', 'Sorcerer', 'Warlock', 'Wizard'],
    'control-flames': ['Druid', 'Sorcerer', 'Wizard'],
    'gust': ['Druid', 'Sorcerer', 'Wizard'],
    'mold-earth': ['Druid', 'Sorcerer', 'Wizard'],
    'shape-water': ['Druid', 'Sorcerer', 'Wizard'],
    'thunderclap': ['Artificer', 'Bard', 'Druid', 'Sorcerer', 'Warlock', 'Wizard'],
    'absorb-elements': ['Artificer', 'Druid', 'Ranger', 'Sorcerer', 'Wizard'],
    'beast-bond': ['Druid', 'Ranger'],
    'catapult': ['Artificer', 'Sorcerer', 'Wizard'],
    'ice-knife': ['Druid', 'Sorcerer', 'Wizard'],
    'snare': ['Artificer', 'Druid', 'Ranger', 'Wizard'],
    'zephyr-strike': ['Ranger'],
    'earth-tremor': ['Bard', 'Druid', 'Sorcerer', 'Wizard'],
    'shadow-blade': ['Sorcerer', 'Warlock', 'Wizard'],
    'healing-spirit': ['Druid', 'Ranger'],
    'tiny-servant': ['Artificer', 'Wizard'],
    'life-transference': ['Cleric', 'Wizard'],
    'enemies-abound': ['Bard', 'Sorcerer', 'Warlock', 'Wizard'],
    'synaptic-static': ['Bard', 'Sorcerer', 'Warlock', 'Wizard'],
    'holy-weapon': ['Cleric', 'Paladin'],
    'steel-wind-strike': ['Ranger', 'Wizard'],
    'dawn': ['Cleric', 'Paladin'],
    'infernal-calling': ['Warlock', 'Wizard'],
    'negative-energy-flood': ['Warlock', 'Wizard'],
    'scatter': ['Sorcerer', 'Warlock', 'Wizard'],
    'crown-of-stars': ['Sorcerer', 'Warlock', 'Wizard'],
    'danse-macabre': ['Warlock', 'Wizard'],
    'soul-cage': ['Warlock', 'Wizard'],
    'maddening-darkness': ['Warlock', 'Wizard'],
    'illusory-dragon': ['Wizard'],
    'psychic-scream': ['Bard', 'Sorcerer', 'Warlock', 'Wizard'],
  };

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

