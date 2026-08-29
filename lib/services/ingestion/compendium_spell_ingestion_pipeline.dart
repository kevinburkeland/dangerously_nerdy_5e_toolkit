import '../../models/domain/core_types.dart';
import '../../models/domain/spell_monster_equipment.dart';
import '../acl/entry_tag_transformer.dart';

/// Ingestion Pipeline mapping compendium spell JSON datasets into modernized domain models.
class CompendiumSpellIngestionPipeline {
  final EntryTagTransformer _transformer;

  CompendiumSpellIngestionPipeline([EntryTagTransformer? transformer])
      : _transformer = transformer ?? EntryTagTransformer();

  /// Ingests a raw compendium spell map into a strongly typed Spell domain model.
  Spell ingestSpell(Map<String, dynamic> raw) {
    final name = raw['name']?.toString() ?? 'Unnamed Spell';
    final slug = _slugify(name);
    final level = (raw['level'] as num?)?.toInt() ?? 0;
    final source = raw['source']?.toString().toUpperCase() ?? 'PHB';

    // Map Ruleset Version
    final ruleset = source.contains('XPHB') || source.contains('SRD52')
        ? RulesetVersion.v2024
        : (source.contains('PHB') || source.contains('SRD')
            ? RulesetVersion.v2014
            : RulesetVersion.homebrew);

    // Map School code to full name
    final schoolCode = raw['school']?.toString().toUpperCase() ?? 'U';
    final school = _mapSchoolCode(schoolCode);

    // Parse Casting Time
    final timeList = raw['time'] as List? ?? [];
    int cost = 1;
    ActionType actionType = ActionType.action;
    String? triggerCondition;

    if (timeList.isNotEmpty && timeList.first is Map) {
      final timeMap = Map<String, dynamic>.from(timeList.first as Map);
      cost = (timeMap['number'] as num?)?.toInt() ?? 1;
      final unit = timeMap['unit']?.toString().toLowerCase() ?? 'action';
      actionType = _mapActionType(unit);
      triggerCondition = timeMap['condition']?.toString();
    }

    // Parse Duration
    final durationList = raw['duration'] as List? ?? [];
    DurationType durationType = DurationType.instantaneous;
    int durationSeconds = 0;
    bool requiresConcentration = false;

    if (durationList.isNotEmpty && durationList.first is Map) {
      final durationMap = Map<String, dynamic>.from(durationList.first as Map);
      final type = durationMap['type']?.toString().toLowerCase() ?? 'instant';
      requiresConcentration = durationMap['concentration'] == true;

      if (type == 'instant') {
        durationType = DurationType.instantaneous;
      } else if (type == 'timed') {
        durationType = DurationType.timed;
        final amount = (durationMap['duration']?['amount'] as num?)?.toInt() ?? 1;
        final unit = durationMap['duration']?['type']?.toString().toLowerCase() ?? 'minute';
        durationSeconds = _calculateSeconds(amount, unit);
      } else if (type == 'permanent') {
        durationType = DurationType.permanent;
      } else {
        durationType = DurationType.special;
      }
    }

    // Parse Range
    final rangeMap = raw['range'] as Map? ?? {};
    final rangeStr = _formatRange(rangeMap);

    // Parse Components
    final compMap = raw['components'] as Map? ?? {};
    final spellComponents = SpellComponents(
      v: compMap['v'] == true,
      s: compMap['s'] == true,
      m: compMap['m'] != null,
      materialDescription: compMap['m'] is String
          ? compMap['m'] as String
          : (compMap['m'] is Map ? compMap['m']['text']?.toString() : null),
      materialCostGp: (compMap['m'] is Map ? compMap['m']['cost'] as num? : null)?.toInt() ?? 0,
      consumesMaterial: compMap['m'] is Map && compMap['m']['consume'] == true,
    );

    // Transform Entries (Description AST -> Markdown)
    final entries = raw['entries'] as List? ?? [];
    final transformed = _transformer.transformEntries(entries);

    // Transform Higher Levels (if present)
    String? higherLevelsMarkdown;
    final higherLevelEntries = raw['entriesHigherLevel'] as List? ?? [];
    if (higherLevelEntries.isNotEmpty) {
      final hlTransformed = _transformer.transformEntries(higherLevelEntries);
      higherLevelsMarkdown = hlTransformed.markdown;
    }

    // Combine extracted evaluation math with damageInflict tags if missing
    var damageMath = transformed.extractedMath;
    if (damageMath.isEmpty && raw['damageInflict'] is List) {
      final inflictList = (raw['damageInflict'] as List).map((e) => e.toString().toLowerCase()).toList();
      if (inflictList.isNotEmpty) {
        final dmgType = DamageType.values.firstWhere(
          (d) => d.name == inflictList.first,
          orElse: () => DamageType.untyped,
        );
        damageMath = [
          EvaluationMath(
            diceFormula: '1d6', // Fallback default formula when tag absent
            damageType: dmgType,
          )
        ];
      }
    }

    return Spell(
      id: EntityId(slug: slug, ruleset: ruleset),
      name: name,
      level: level,
      school: school,
      castingTime: CastingTime(
        cost: cost,
        actionType: actionType,
        triggerCondition: triggerCondition,
      ),
      duration: SpellDuration(
        type: durationType,
        durationSeconds: durationSeconds,
        requiresConcentration: requiresConcentration,
      ),
      range: rangeStr,
      components: spellComponents,
      descriptionMarkdown: transformed.markdown,
      higherLevelsMarkdown: higherLevelsMarkdown,
      damageMath: damageMath,
      relatedEntityRefs: transformed.extractedRefs,
    );
  }

  String _slugify(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r"['’]"), '')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }

  String _mapSchoolCode(String code) {
    switch (code) {
      case 'A':
        return 'Abjuration';
      case 'C':
        return 'Conjuration';
      case 'D':
        return 'Divination';
      case 'E':
        return 'Enchantment';
      case 'V':
        return 'Evocation';
      case 'I':
        return 'Illusion';
      case 'N':
        return 'Necromancy';
      case 'T':
        return 'Transmutation';
      default:
        return 'Universal';
    }
  }

  ActionType _mapActionType(String unit) {
    switch (unit) {
      case 'action':
        return ActionType.action;
      case 'bonus':
        return ActionType.bonusAction;
      case 'reaction':
        return ActionType.reaction;
      case 'minute':
        return ActionType.minute;
      case 'hour':
        return ActionType.hour;
      default:
        return ActionType.special;
    }
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
        return amount;
    }
  }

  String _formatRange(Map rangeMap) {
    final type = rangeMap['type']?.toString();
    final distance = rangeMap['distance'] as Map? ?? {};
    final amount = distance['amount'];
    final distType = distance['type']?.toString();

    if (type == 'point') {
      if (distType == 'self') return 'Self';
      if (distType == 'touch') return 'Touch';
      if (distType == 'sight') return 'Sight';
      if (distType == 'unlimited') return 'Unlimited';
      if (amount != null && distType != null) return '$amount $distType';
    } else if (type == 'radius' || type == 'sphere' || type == 'cone' || type == 'line' || type == 'cube' || type == 'emanation') {
      return 'Self ($amount-$distType $type)';
    } else if (type == 'special') {
      return 'Special';
    }
    return 'Self';
  }
}
