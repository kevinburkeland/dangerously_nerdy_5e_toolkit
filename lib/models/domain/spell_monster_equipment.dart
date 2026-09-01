import 'package:flutter/foundation.dart';
import 'core_types.dart';
import 'entity_reference.dart';
import 'feature_grant.dart';

/// Isolated mathematical formula for damage and dice evaluation
@immutable
class EvaluationMath {
  final String diceFormula; // e.g. "8d6"
  final DamageType damageType;
  final String? scalingFormula; // e.g. "+1d6 per slot above 3rd"

  const EvaluationMath({
    required this.diceFormula,
    required this.damageType,
    this.scalingFormula,
  });

  Map<String, dynamic> toMap() => {
        'diceFormula': diceFormula,
        'damageType': damageType.name,
        'scalingFormula': scalingFormula,
      };

  factory EvaluationMath.fromMap(Map<String, dynamic> map) {
    final dmgStr = map['damageType']?.toString() ?? 'untyped';
    final damageType = DamageType.values.firstWhere(
      (d) => d.name == dmgStr,
      orElse: () => DamageType.untyped,
    );
    return EvaluationMath(
      diceFormula: map['diceFormula']?.toString() ?? '',
      damageType: damageType,
      scalingFormula: map['scalingFormula']?.toString(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EvaluationMath &&
          runtimeType == other.runtimeType &&
          diceFormula == other.diceFormula &&
          damageType == other.damageType &&
          scalingFormula == other.scalingFormula;

  @override
  int get hashCode =>
      diceFormula.hashCode ^ damageType.hashCode ^ scalingFormula.hashCode;

  @override
  String toString() => '$diceFormula ${damageType.name}';
}

/// Standardized spell component flags
@immutable
class SpellComponents {
  final bool v;
  final bool s;
  final bool m;
  final String? materialDescription;
  final int materialCostGp;
  final bool consumesMaterial;

  const SpellComponents({
    this.v = false,
    this.s = false,
    this.m = false,
    this.materialDescription,
    this.materialCostGp = 0,
    this.consumesMaterial = false,
  });

  Map<String, dynamic> toMap() => {
        'v': v,
        's': s,
        'm': m,
        'materialDescription': materialDescription,
        'materialCostGp': materialCostGp,
        'consumesMaterial': consumesMaterial,
      };

  factory SpellComponents.fromMap(Map<String, dynamic> map) {
    return SpellComponents(
      v: map['v'] == true,
      s: map['s'] == true,
      m: map['m'] == true,
      materialDescription: map['materialDescription']?.toString(),
      materialCostGp: (map['materialCostGp'] as num?)?.toInt() ?? 0,
      consumesMaterial: map['consumesMaterial'] == true,
    );
  }
}

/// Flattened casting time model
@immutable
class CastingTime {
  final int cost;
  final ActionType actionType;
  final String? triggerCondition;

  const CastingTime({
    required this.cost,
    required this.actionType,
    this.triggerCondition,
  });

  Map<String, dynamic> toMap() => {
        'cost': cost,
        'actionType': actionType.name,
        'triggerCondition': triggerCondition,
      };

  factory CastingTime.fromMap(Map<String, dynamic> map) {
    final typeStr = map['actionType']?.toString() ?? 'action';
    final actionType = ActionType.values.firstWhere(
      (a) => a.name == typeStr,
      orElse: () => ActionType.action,
    );
    return CastingTime(
      cost: (map['cost'] as num?)?.toInt() ?? 1,
      actionType: actionType,
      triggerCondition: map['triggerCondition']?.toString(),
    );
  }
}

/// Flattened duration model with concentration flag
@immutable
class SpellDuration {
  final DurationType type;
  final int durationSeconds;
  final bool requiresConcentration;
  final String? rawText;

  const SpellDuration({
    required this.type,
    this.durationSeconds = 0,
    this.requiresConcentration = false,
    this.rawText,
  });

  Map<String, dynamic> toMap() => {
        'type': type.name,
        'durationSeconds': durationSeconds,
        'requiresConcentration': requiresConcentration,
        'rawText': rawText,
      };

  factory SpellDuration.fromMap(Map<String, dynamic> map) {
    final typeStr = map['type']?.toString() ?? 'instantaneous';
    final type = DurationType.values.firstWhere(
      (d) => d.name == typeStr,
      orElse: () => DurationType.instantaneous,
    );
    return SpellDuration(
      type: type,
      durationSeconds: (map['durationSeconds'] as num?)?.toInt() ?? 0,
      requiresConcentration: map['requiresConcentration'] == true,
      rawText: map['rawText']?.toString(),
    );
  }
}

/// Modernized Spell Domain Model
@immutable
class Spell extends DomainEntity {
  @override
  final EntityId id;
  @override
  final String name;
  final int level;
  final String school;
  final CastingTime castingTime;
  final SpellDuration duration;
  final String range;
  final SpellComponents components;
  final String descriptionMarkdown;
  final String? higherLevelsMarkdown;
  final List<EvaluationMath> damageMath;
  final List<EntityReference<DomainEntity>> relatedEntityRefs;
  @override
  final Map<String, dynamic> customProperties;

  const Spell({
    required this.id,
    required this.name,
    required this.level,
    required this.school,
    required this.castingTime,
    required this.duration,
    required this.range,
    required this.components,
    required this.descriptionMarkdown,
    this.higherLevelsMarkdown,
    this.damageMath = const [],
    this.relatedEntityRefs = const [],
    this.customProperties = const {},
  });

  @override
  EntityType get entityType => EntityType.spell;

  @override
  Map<String, dynamic> toMap() => {
        'id': id.toMap(),
        'name': name,
        'level': level,
        'school': school,
        'castingTime': castingTime.toMap(),
        'duration': duration.toMap(),
        'range': range,
        'components': components.toMap(),
        'descriptionMarkdown': descriptionMarkdown,
        'higherLevelsMarkdown': higherLevelsMarkdown,
        'damageMath': damageMath.map((d) => d.toMap()).toList(),
        'relatedEntityRefs': relatedEntityRefs.map((r) => r.toMap()).toList(),
        'customProperties': customProperties,
      };

  factory Spell.fromMap(Map<String, dynamic> map) {
    return Spell(
      id: EntityId.fromMap(Map<String, dynamic>.from(map['id'] as Map? ?? {})),
      name: map['name']?.toString() ?? '',
      level: (map['level'] as num?)?.toInt() ?? 0,
      school: map['school']?.toString() ?? 'Universal',
      castingTime: CastingTime.fromMap(
          Map<String, dynamic>.from(map['castingTime'] as Map? ?? {})),
      duration: SpellDuration.fromMap(
          Map<String, dynamic>.from(map['duration'] as Map? ?? {})),
      range: map['range']?.toString() ?? 'Self',
      components: SpellComponents.fromMap(
          Map<String, dynamic>.from(map['components'] as Map? ?? {})),
      descriptionMarkdown: map['descriptionMarkdown']?.toString() ?? '',
      higherLevelsMarkdown: map['higherLevelsMarkdown']?.toString(),
      damageMath: (map['damageMath'] as List? ?? [])
          .whereType<Map>()
          .map((d) => EvaluationMath.fromMap(Map<String, dynamic>.from(d)))
          .toList(),
      relatedEntityRefs: (map['relatedEntityRefs'] as List? ?? [])
          .whereType<Map>()
          .map((r) => EntityReference.fromMap(Map<String, dynamic>.from(r)))
          .toList(),
      customProperties:
          Map<String, dynamic>.from(map['customProperties'] as Map? ?? {}),
    );
  }

  Spell copyWith({
    EntityId? id,
    String? name,
    int? level,
    String? school,
    CastingTime? castingTime,
    SpellDuration? duration,
    String? range,
    SpellComponents? components,
    String? descriptionMarkdown,
    String? higherLevelsMarkdown,
    List<EvaluationMath>? damageMath,
    List<EntityReference<DomainEntity>>? relatedEntityRefs,
    Map<String, dynamic>? customProperties,
  }) {
    return Spell(
      id: id ?? this.id,
      name: name ?? this.name,
      level: level ?? this.level,
      school: school ?? this.school,
      castingTime: castingTime ?? this.castingTime,
      duration: duration ?? this.duration,
      range: range ?? this.range,
      components: components ?? this.components,
      descriptionMarkdown: descriptionMarkdown ?? this.descriptionMarkdown,
      higherLevelsMarkdown: higherLevelsMarkdown ?? this.higherLevelsMarkdown,
      damageMath: damageMath ?? this.damageMath,
      relatedEntityRefs: relatedEntityRefs ?? this.relatedEntityRefs,
      customProperties: customProperties ?? this.customProperties,
    );
  }
}

/// Modernized Monster Domain Model
@immutable
class Monster extends DomainEntity {
  @override
  final EntityId id;
  @override
  final String name;
  final String size;
  final String monsterType;
  final String alignment;
  final int armorClass;
  final int hitPoints;
  final String hitDieFormula;
  final String challengeRating;
  final String actionsMarkdown;
  final List<EntityReference<Spell>> innateSpells;
  final List<EvaluationMath> attackMath;
  @override
  final Map<String, dynamic> customProperties;

  const Monster({
    required this.id,
    required this.name,
    required this.size,
    required this.monsterType,
    required this.alignment,
    required this.armorClass,
    required this.hitPoints,
    required this.hitDieFormula,
    required this.challengeRating,
    required this.actionsMarkdown,
    this.innateSpells = const [],
    this.attackMath = const [],
    this.customProperties = const {},
  });

  @override
  EntityType get entityType => EntityType.monster;

  @override
  Map<String, dynamic> toMap() => {
        'id': id.toMap(),
        'name': name,
        'size': size,
        'monsterType': monsterType,
        'alignment': alignment,
        'armorClass': armorClass,
        'hitPoints': hitPoints,
        'hitDieFormula': hitDieFormula,
        'challengeRating': challengeRating,
        'actionsMarkdown': actionsMarkdown,
        'innateSpells': innateSpells.map((s) => s.toMap()).toList(),
        'attackMath': attackMath.map((a) => a.toMap()).toList(),
        'customProperties': customProperties,
      };

  factory Monster.fromMap(Map<String, dynamic> map) {
    return Monster(
      id: EntityId.fromMap(Map<String, dynamic>.from(map['id'] as Map? ?? {})),
      name: map['name']?.toString() ?? '',
      size: map['size']?.toString() ?? 'Medium',
      monsterType: map['monsterType']?.toString() ?? 'Humanoid',
      alignment: map['alignment']?.toString() ?? 'unaligned',
      armorClass: (map['armorClass'] as num?)?.toInt() ?? 10,
      hitPoints: (map['hitPoints'] as num?)?.toInt() ?? 10,
      hitDieFormula: map['hitDieFormula']?.toString() ?? '2d8',
      challengeRating: map['challengeRating']?.toString() ?? '1',
      actionsMarkdown: map['actionsMarkdown']?.toString() ?? '',
      innateSpells: (map['innateSpells'] as List? ?? [])
          .whereType<Map>()
          .map((s) =>
              EntityReference<Spell>.fromMap(Map<String, dynamic>.from(s)))
          .toList(),
      attackMath: (map['attackMath'] as List? ?? [])
          .whereType<Map>()
          .map((a) => EvaluationMath.fromMap(Map<String, dynamic>.from(a)))
          .toList(),
      customProperties:
          Map<String, dynamic>.from(map['customProperties'] as Map? ?? {}),
    );
  }

  Monster copyWith({
    EntityId? id,
    String? name,
    String? size,
    String? monsterType,
    String? alignment,
    int? armorClass,
    int? hitPoints,
    String? hitDieFormula,
    String? challengeRating,
    String? actionsMarkdown,
    List<EntityReference<Spell>>? innateSpells,
    List<EvaluationMath>? attackMath,
    Map<String, dynamic>? customProperties,
  }) {
    return Monster(
      id: id ?? this.id,
      name: name ?? this.name,
      size: size ?? this.size,
      monsterType: monsterType ?? this.monsterType,
      alignment: alignment ?? this.alignment,
      armorClass: armorClass ?? this.armorClass,
      hitPoints: hitPoints ?? this.hitPoints,
      hitDieFormula: hitDieFormula ?? this.hitDieFormula,
      challengeRating: challengeRating ?? this.challengeRating,
      actionsMarkdown: actionsMarkdown ?? this.actionsMarkdown,
      innateSpells: innateSpells ?? this.innateSpells,
      attackMath: attackMath ?? this.attackMath,
      customProperties: customProperties ?? this.customProperties,
    );
  }
}

/// Modernized Equipment Item Domain Model
@immutable
class EquipmentItem extends DomainEntity {
  @override
  final EntityId id;
  @override
  final String name;
  final String itemType;
  final String rarity;
  final bool requiresAttunement;
  final String descriptionMarkdown;
  /// Declarative mechanic grants emitted when this item is equipped (e.g., AC bonus, speed bonus).
  final List<FeatureGrant> grants;
  @override
  final Map<String, dynamic> customProperties;

  const EquipmentItem({
    required this.id,
    required this.name,
    required this.itemType,
    required this.rarity,
    required this.requiresAttunement,
    required this.descriptionMarkdown,
    this.grants = const [],
    this.customProperties = const {},
  });

  @override
  EntityType get entityType => EntityType.equipment;

  @override
  Map<String, dynamic> toMap() => {
        'id': id.toMap(),
        'name': name,
        'itemType': itemType,
        'rarity': rarity,
        'requiresAttunement': requiresAttunement,
        'descriptionMarkdown': descriptionMarkdown,
        'grants': grants.map((g) => g.toMap()).toList(),
        'customProperties': customProperties,
      };

  factory EquipmentItem.fromMap(Map<String, dynamic> map) {
    return EquipmentItem(
      id: EntityId.fromMap(Map<String, dynamic>.from(map['id'] as Map? ?? {})),
      name: map['name']?.toString() ?? '',
      itemType: map['itemType']?.toString() ?? 'Wondrous Item',
      rarity: map['rarity']?.toString() ?? 'Common',
      requiresAttunement: map['requiresAttunement'] == true,
      descriptionMarkdown: map['descriptionMarkdown']?.toString() ?? '',
      grants: (map['grants'] as List? ?? [])
          .whereType<Map>()
          .map((g) => FeatureGrant.fromMap(Map<String, dynamic>.from(g)))
          .toList(),
      customProperties:
          Map<String, dynamic>.from(map['customProperties'] as Map? ?? {}),
    );
  }

  EquipmentItem copyWith({
    EntityId? id,
    String? name,
    String? itemType,
    String? rarity,
    bool? requiresAttunement,
    String? descriptionMarkdown,
    List<FeatureGrant>? grants,
    Map<String, dynamic>? customProperties,
  }) {
    return EquipmentItem(
      id: id ?? this.id,
      name: name ?? this.name,
      itemType: itemType ?? this.itemType,
      rarity: rarity ?? this.rarity,
      requiresAttunement: requiresAttunement ?? this.requiresAttunement,
      descriptionMarkdown: descriptionMarkdown ?? this.descriptionMarkdown,
      grants: grants ?? this.grants,
      customProperties: customProperties ?? this.customProperties,
    );
  }
}
