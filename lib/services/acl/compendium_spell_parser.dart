import '../../models/domain/core_types.dart';
import '../../models/domain/spell_monster_equipment.dart';
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
    final castingTime = _parseCastingTime(raw['time']);

    // Duration
    final duration = _parseDuration(raw['duration']);

    // Range
    final rangeStr = _parseRange(raw['range']);

    // Components
    final components = _parseComponents(raw['components']);

    // Markdown description entries
    final transformed = transformer.transformEntries(
      raw['entries'],
      defaultRuleset: ruleset,
    );

    // Higher level entries
    String? higherLevelsMarkdown;
    if (raw['entriesHigherLevel'] != null) {
      final hl = transformer.transformEntries(
        raw['entriesHigherLevel'],
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

    // Capture all auxiliary & unmapped fields in customProperties to guarantee 0% data loss
    final customProperties = <String, dynamic>{};
    raw.forEach((key, value) {
      if (!_standardSpellKeys.contains(key)) {
        customProperties[key] = value;
      }
    });

    // Also store explicit class list metadata if present
    if (raw.containsKey('classes')) {
      customProperties['classes'] = raw['classes'];
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
    'duration',
    'range',
    'components',
    'entries',
    'entriesHigherLevel',
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
      }
    } else if (timeData is Map) {
      cost = (timeData['number'] as num?)?.toInt() ?? 1;
      final unit = timeData['unit']?.toString().toLowerCase() ?? 'action';
      actionType = _mapActionType(unit);
      triggerCondition = timeData['condition']?.toString();
    }

    return CastingTime(
      cost: cost,
      actionType: actionType,
      triggerCondition: triggerCondition,
    );
  }

  ActionType _mapActionType(String unit) {
    switch (unit) {
      case 'bonus':
      case 'bonus action':
        return ActionType.bonusAction;
      case 'reaction':
        return ActionType.reaction;
      case 'minute':
        return ActionType.minute;
      case 'hour':
        return ActionType.hour;
      case 'special':
        return ActionType.special;
      case 'action':
      default:
        return ActionType.action;
    }
  }

  SpellDuration _parseDuration(dynamic durationData) {
    DurationType durationType = DurationType.instantaneous;
    int durationSeconds = 0;
    bool requiresConcentration = false;
    String? rawText;

    if (durationData is List && durationData.isNotEmpty) {
      final first = durationData.first;
      if (first is Map) {
        final type = first['type']?.toString().toLowerCase() ?? 'instant';
        requiresConcentration = first['concentration'] == true;

        if (type == 'instant') {
          durationType = DurationType.instantaneous;
        } else if (type == 'timed' && first['duration'] is Map) {
          durationType = DurationType.timed;
          final d = first['duration'] as Map;
          final amount = (d['amount'] as num?)?.toInt() ?? 1;
          final unit = d['type']?.toString().toLowerCase() ?? 'minute';
          durationSeconds = _calculateSeconds(amount, unit);
          rawText = '$amount $unit${amount > 1 ? 's' : ''}';
        } else if (type == 'permanent') {
          durationType = DurationType.permanent;
          rawText = 'Permanent';
        } else {
          durationType = DurationType.special;
          rawText = 'Special';
        }
      }
    } else if (durationData is Map) {
      final type = durationData['type']?.toString().toLowerCase() ?? 'instant';
      requiresConcentration = durationData['concentration'] == true;
      if (type == 'timed' && durationData['duration'] is Map) {
        durationType = DurationType.timed;
        final d = durationData['duration'] as Map;
        final amount = (d['amount'] as num?)?.toInt() ?? 1;
        final unit = d['type']?.toString().toLowerCase() ?? 'minute';
        durationSeconds = _calculateSeconds(amount, unit);
      } else if (type == 'permanent') {
        durationType = DurationType.permanent;
      }
    }

    return SpellDuration(
      type: durationType,
      durationSeconds: durationSeconds,
      requiresConcentration: requiresConcentration,
      rawText: rawText,
    );
  }

  int _calculateSeconds(int amount, String unit) {
    switch (unit) {
      case 'round':
        return amount * 6;
      case 'minute':
        return amount * 60;
      case 'hour':
        return amount * 3600;
      case 'day':
        return amount * 86400;
      default:
        return amount * 60;
    }
  }

  String _parseRange(dynamic rangeData) {
    if (rangeData == null) return 'Self';
    if (rangeData is String) return rangeData;

    if (rangeData is Map) {
      final type = rangeData['type']?.toString().toLowerCase();
      final dist = rangeData['distance'] as Map?;

      if (dist != null) {
        final amount = dist['amount'];
        final distType = dist['type']?.toString().toLowerCase();
        if (distType == 'feet' || distType == 'miles' || distType == 'yards') {
          return '$amount $distType${type != null && type != 'point' ? ' ($type)' : ''}';
        } else if (distType == 'touch') {
          return 'Touch';
        } else if (distType == 'self') {
          return 'Self';
        } else if (distType == 'sight') {
          return 'Sight';
        } else if (distType == 'unlimited') {
          return 'Unlimited';
        }
      }

      switch (type) {
        case 'point':
          return 'Point';
        case 'touch':
          return 'Touch';
        case 'self':
          return 'Self';
        case 'special':
          return 'Special';
        default:
          return type != null ? type[0].toUpperCase() + type.substring(1) : 'Self';
      }
    }

    return 'Self';
  }

  SpellComponents _parseComponents(dynamic compData) {
    if (compData == null) {
      return const SpellComponents();
    }

    if (compData is Map) {
      final v = compData['v'] == true;
      final s = compData['s'] == true;
      final mRaw = compData['m'];

      bool m = mRaw != null && mRaw != false;
      String? materialDesc;
      int materialCostGp = 0;
      bool consumes = false;

      if (mRaw is String) {
        materialDesc = mRaw;
      } else if (mRaw is Map) {
        materialDesc = mRaw['text']?.toString();
        consumes = mRaw['consume'] == true;
        final costRaw = mRaw['cost'];
        if (costRaw is num) {
          materialCostGp = (costRaw / 100).round(); // Compendium standard uses cp for cost integer or direct gp
          if (materialCostGp == 0 && costRaw > 0) {
            materialCostGp = costRaw.toInt();
          }
        }
      }

      return SpellComponents(
        v: v,
        s: s,
        m: m,
        materialDescription: materialDesc,
        materialCostGp: materialCostGp,
        consumesMaterial: consumes,
      );
    }

    return const SpellComponents();
  }

  String _mapSchool(String code) {
    switch (code) {
      case 'A':
        return 'Abjuration';
      case 'C':
        return 'Conjuration';
      case 'D':
        return 'Divination';
      case 'E':
        return 'Enchantment';
      case 'I':
        return 'Illusion';
      case 'N':
        return 'Necromancy';
      case 'T':
        return 'Transmutation';
      case 'V':
        return 'Evocation';
      default:
        if (code.length > 2) {
          return code[0].toUpperCase() + code.substring(1).toLowerCase();
        }
        return 'Universal';
    }
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
