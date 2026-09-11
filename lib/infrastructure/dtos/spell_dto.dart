import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../models/domain/core_types.dart';
import '../../models/domain/entity_reference.dart';
import '../../models/domain/spell_monster_equipment.dart';
import '../mappers/homebrew_ingestor.dart';

/// Data Transfer Object for [Spell], isolating full document serialization,
/// legacy unparsed payload preservation, and external ACL boundary transformations
/// to the Infrastructure layer.
@immutable
class SpellDto {
  final String id;
  final String name;
  final int level;
  final String school;
  final String castingTime;
  final String duration;
  final String range;
  final int rangeDistanceFeet;
  final String rangeType;
  final String damageType;
  final SpellComponents components;
  final String descriptionMarkdown;
  final String? higherLevelsMarkdown;
  final List<EvaluationMath> damageMath;
  final List<EntityReference<DomainEntity>> relatedEntityRefs;
  final Map<String, dynamic> customProperties;
  final Map<String, dynamic> unparsedPayload;
  final Map<String, dynamic> _rawMap;
  Map<String, dynamic> get rawMap => _rawMap;

  const SpellDto({
    required this.id,
    required this.name,
    this.level = 0,
    this.school = 'Universal',
    this.castingTime = '1 action',
    this.duration = 'Instantaneous',
    this.range = 'Self',
    this.rangeDistanceFeet = 0,
    this.rangeType = 'ranged',
    this.damageType = 'untyped',
    this.components = const SpellComponents(),
    this.descriptionMarkdown = '',
    this.higherLevelsMarkdown,
    this.damageMath = const [],
    this.relatedEntityRefs = const [],
    this.customProperties = const {},
    this.unparsedPayload = const {},
    Map<String, dynamic>? rawMap,
  }) : _rawMap = rawMap ?? const {};

  /// Deserializes a raw Map payload into [SpellDto] while scooping unknown keys
  /// into [unparsedPayload] and clamping core numeric attributes safely.
  factory SpellDto.fromJson(Map<String, dynamic> json) {
    const knownKeys = {
      'id',
      'slug',
      'name',
      'level',
      'school',
      'castingTime',
      'duration',
      'range',
      'rangeDistanceFeet',
      'rangeType',
      'damageType',
      'components',
      'description',
      'descriptionMarkdown',
      'higherLevelsMarkdown',
      'higherLevels',
      'entriesHigherLevel',
      'damageMath',
      'relatedEntityRefs',
      'customProperties',
    };

    final unparsed = <String, dynamic>{};
    json.forEach((key, value) {
      if (!knownKeys.contains(key)) {
        unparsed[key] = value;
      }
    });

    // ID resolution
    String resolvedId = '';
    if (json['id'] is String && (json['id'] as String).isNotEmpty) {
      resolvedId = json['id'] as String;
    } else if (json['id'] is Map && (json['id'] as Map)['slug'] is String) {
      resolvedId = (json['id'] as Map)['slug'] as String;
    } else if (json['slug'] is String) {
      resolvedId = json['slug'] as String;
    }

    final resolvedName = json['name']?.toString() ?? '';
    final resolvedLevel = (json['level'] is num ? (json['level'] as num).toInt() : 0).clamp(0, 9);
    final resolvedSchool = json['school']?.toString() ?? 'Universal';

    // Casting time resolution
    String resolvedCastingTime = '1 action';
    if (json['castingTime'] is String) {
      resolvedCastingTime = json['castingTime'] as String;
    } else if (json['castingTime'] is Map) {
      final ctMap = json['castingTime'] as Map;
      final cost = ctMap['cost'] ?? 1;
      final type = ctMap['actionType'] ?? 'action';
      resolvedCastingTime = '$cost $type';
    }

    // Duration resolution
    String resolvedDuration = 'Instantaneous';
    if (json['duration'] is String) {
      resolvedDuration = json['duration'] as String;
    } else if (json['duration'] is Map) {
      final durMap = json['duration'] as Map;
      resolvedDuration = durMap['rawText']?.toString() ?? durMap['type']?.toString() ?? 'Instantaneous';
    }

    final resolvedRange = json['range']?.toString() ?? 'Self';
    final resolvedDescription = json['descriptionMarkdown']?.toString() ?? json['description']?.toString() ?? '';
    final resolvedHigherLevels = json['higherLevelsMarkdown']?.toString() ??
        json['higherLevels']?.toString() ??
        (json['entriesHigherLevel'] is List
            ? (json['entriesHigherLevel'] as List).join('\n')
            : json['entriesHigherLevel']?.toString());

    final rangeInfo = HomebrewIngestor.normalizeRange(
      json['range'] ?? resolvedRange,
      resolvedDescription,
    );
    final resolvedRangeDistance = (rangeInfo['rangeDistanceFeet'] as int?) ??
        (json['rangeDistanceFeet'] as num?)?.toInt() ??
        0;
    final resolvedRangeType = (rangeInfo['rangeType'] as String?) ??
        json['rangeType']?.toString() ??
        'ranged';

    // Components resolution
    SpellComponents resolvedComponents = const SpellComponents();
    if (json['components'] is Map) {
      resolvedComponents = SpellComponents.fromMap(Map<String, dynamic>.from(json['components'] as Map));
    }

    // Damage math resolution
    var resolvedDamageMath = <EvaluationMath>[];
    if (json['damageMath'] is List) {
      for (final dm in json['damageMath'] as List) {
        if (dm is Map) {
          try {
            resolvedDamageMath.add(EvaluationMath.fromMap(Map<String, dynamic>.from(dm)));
          } catch (_) {}
        }
      }
    } else if (json['damageMath'] is Map) {
      try {
        resolvedDamageMath.add(EvaluationMath.fromMap(Map<String, dynamic>.from(json['damageMath'] as Map)));
      } catch (_) {}
    }

    // If damageMath was not explicitly supplied, extract from markdown/text
    if (resolvedDamageMath.isEmpty && resolvedDescription.isNotEmpty) {
      final damageRegex = RegExp(
        r'(?:\{@damage\s+)?(\d+d\d+)(?:\|([a-zA-Z]+))?\}?|\b(\d+d\d+)\s*(acid|bludgeoning|cold|fire|force|lightning|necrotic|piercing|poison|psychic|radiant|slashing|thunder)?\b',
        caseSensitive: false,
      );
      for (final m in damageRegex.allMatches(resolvedDescription)) {
        final formula = m.group(1) ?? m.group(3) ?? '';
        final typeStr = m.group(2) ?? m.group(4);
        if (formula.isNotEmpty) {
          resolvedDamageMath.add(EvaluationMath(
            diceFormula: formula,
            damageType: DamageType.fromLooseString(typeStr),
          ));
        }
      }
    }

    // Correct any mislabeled damage types from the description before scaling & delivery enrichment
    resolvedDamageMath = HomebrewIngestor.correctDamageTypesFromDescription(
      resolvedDamageMath,
      resolvedDescription,
    );

    // Extract higher levels scaling dice formula into damageMath.scalingFormula
    final extractedScaling = HomebrewIngestor.extractHigherLevelsDice(resolvedHigherLevels);
    if (extractedScaling != null && resolvedDamageMath.isNotEmpty) {
      bool applied = false;
      for (var i = 0; i < resolvedDamageMath.length; i++) {
        final dm = resolvedDamageMath[i];
        if (dm.scalingFormula == null || dm.scalingFormula!.isEmpty) {
          final typeName = dm.damageType.name.toLowerCase();
          final mentionsType = resolvedHigherLevels != null &&
              typeName != 'untyped' &&
              resolvedHigherLevels.toLowerCase().contains(typeName);
          if (mentionsType || resolvedDamageMath.length == 1) {
            resolvedDamageMath[i] = dm.copyWith(scalingFormula: extractedScaling);
            applied = true;
          }
        }
      }
      if (!applied) {
        for (var i = 0; i < resolvedDamageMath.length; i++) {
          final dm = resolvedDamageMath[i];
          if (dm.scalingFormula == null || dm.scalingFormula!.isEmpty) {
            resolvedDamageMath[i] = dm.copyWith(scalingFormula: extractedScaling);
            break;
          }
        }
      }
    }

    // Variable damage type resolution (Chromatic Orb, Chaos Bolt, etc.)
    final computedMathType = resolvedDamageMath.isNotEmpty &&
            resolvedDamageMath.first.damageType != DamageType.untyped
        ? resolvedDamageMath.first.damageType.name
        : null;

    final fallbackType = json['damageType']?.toString() ?? 'untyped';
    final baseType = computedMathType ?? fallbackType;

    final resolvedDamageType = HomebrewIngestor.resolveDamageType(
      '$resolvedName $resolvedDescription ${resolvedHigherLevels ?? ''}',
      baseType,
    );

    if (resolvedDamageType == 'variable') {
      for (var i = 0; i < resolvedDamageMath.length; i++) {
        final dm = resolvedDamageMath[i];
        if (dm.damageType == DamageType.acid ||
            dm.damageType == DamageType.untyped ||
            resolvedDamageMath.length == 1) {
          resolvedDamageMath[i] = dm.copyWith(damageType: DamageType.variable);
        }
      }
    }

    // Enrich damage delivery methods (isAttackRoll, requiresSave)
    final enrichedDamageMath = HomebrewIngestor.enrichDamageDelivery(
      resolvedDamageMath,
      '$resolvedDescription ${resolvedHigherLevels ?? ''}',
    );

    // Related entity refs resolution
    final resolvedRefs = <EntityReference<DomainEntity>>[];
    if (json['relatedEntityRefs'] is List) {
      for (final ref in json['relatedEntityRefs'] as List) {
        if (ref is Map) {
          try {
            resolvedRefs.add(EntityReference.fromMap(Map<String, dynamic>.from(ref)));
          } catch (_) {}
        }
      }
    }

    final resolvedCustomProps = json['customProperties'] is Map
        ? Map<String, dynamic>.from(json['customProperties'] as Map)
        : <String, dynamic>{};

    return SpellDto(
      id: resolvedId,
      name: resolvedName,
      level: resolvedLevel,
      school: resolvedSchool,
      castingTime: resolvedCastingTime,
      duration: resolvedDuration,
      range: resolvedRange,
      rangeDistanceFeet: resolvedRangeDistance,
      rangeType: resolvedRangeType,
      damageType: resolvedDamageType,
      components: resolvedComponents,
      descriptionMarkdown: resolvedDescription,
      higherLevelsMarkdown: resolvedHigherLevels,
      damageMath: enrichedDamageMath,
      relatedEntityRefs: resolvedRefs,
      customProperties: resolvedCustomProps,
      unparsedPayload: unparsed,
      rawMap: Map<String, dynamic>.from(json),
    );
  }

  /// Deserializes a raw Map payload into [SpellDto].
  factory SpellDto.fromMap(Map<String, dynamic> map) => SpellDto.fromJson(map);

  /// Deserializes from a JSON string.
  factory SpellDto.fromJsonString(String jsonStr) {
    return SpellDto.fromJson(Map<String, dynamic>.from(json.decode(jsonStr) as Map));
  }

  /// Factory creating a DTO from a pure domain [Spell].
  factory SpellDto.fromDomain(Spell spell) {
    return SpellDto(
      id: spell.id.slug,
      name: spell.name,
      level: spell.level,
      school: spell.school,
      castingTime: spell.castingTime.triggerCondition ?? '${spell.castingTime.cost} ${spell.castingTime.actionType.name}',
      duration: spell.duration.rawText ?? spell.duration.type.name,
      range: spell.range,
      rangeDistanceFeet: spell.rangeDistanceFeet,
      rangeType: spell.rangeType,
      damageType: spell.damageType ?? (spell.damageMath.isNotEmpty ? spell.damageMath.first.damageType.name : 'untyped'),
      components: spell.components,
      descriptionMarkdown: spell.descriptionMarkdown,
      higherLevelsMarkdown: spell.higherLevelsMarkdown,
      damageMath: spell.damageMath,
      relatedEntityRefs: spell.relatedEntityRefs,
      customProperties: spell.customProperties,
      unparsedPayload: const {},
      rawMap: spell.toMap(),
    );
  }

  /// Converts this DTO into a domain [Spell] entity.
  Spell toDomain() {
    final entityId = EntityId(
      slug: id,
      ruleset: RulesetVersion.homebrew,
    );

    final mergedCustomProps = <String, dynamic>{
      ...customProperties,
      ...unparsedPayload,
    };

    return Spell(
      id: entityId,
      name: name,
      level: level,
      school: school,
      castingTime: CastingTime(
        cost: 1,
        actionType: ActionType.action,
        triggerCondition: castingTime,
      ),
      duration: SpellDuration(
        type: DurationType.instantaneous,
        rawText: duration,
      ),
      range: range,
      rangeDistanceFeet: rangeDistanceFeet,
      rangeType: rangeType,
      damageType: damageType,
      components: components,
      descriptionMarkdown: descriptionMarkdown,
      higherLevelsMarkdown: higherLevelsMarkdown,
      damageMath: damageMath,
      relatedEntityRefs: relatedEntityRefs,
      customProperties: mergedCustomProps,
    );
  }

  /// Serializes to a Map with unparsed homebrew fields preserved.
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'id': id,
      'name': name,
      'level': level,
      'school': school,
      'castingTime': castingTime,
      'duration': duration,
      'range': range,
      'rangeDistanceFeet': rangeDistanceFeet,
      'rangeType': rangeType,
      'damageType': damageType,
      'components': components.toMap(),
      'descriptionMarkdown': descriptionMarkdown,
    };

    if (higherLevelsMarkdown != null) {
      map['higherLevelsMarkdown'] = higherLevelsMarkdown;
    }
    if (damageMath.isNotEmpty) {
      map['damageMath'] = damageMath.map((d) => d.toMap()).toList();
    }
    if (relatedEntityRefs.isNotEmpty) {
      map['relatedEntityRefs'] = relatedEntityRefs.map((r) => r.toMap()).toList();
    }
    if (customProperties.isNotEmpty) {
      map['customProperties'] = customProperties;
    }

    // Merge unparsed payload keys back in
    unparsedPayload.forEach((key, value) {
      if (!map.containsKey(key)) {
        map[key] = value;
      }
    });

    return map;
  }

  /// Serializes to a JSON map representation.
  Map<String, dynamic> toJson() => toMap();

  /// Serializes to a JSON string.
  String toJsonString() => json.encode(toMap());
}
