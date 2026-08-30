import 'package:flutter/foundation.dart';
import 'core_types.dart';

/// Base contract for all identifiable domain entities.
abstract class DomainEntity {
  EntityId get id;
  String get name;
  EntityType get entityType;
  RulesetVersion get ruleset => id.ruleset;
  String get slug => id.slug;
  Map<String, dynamic> get customProperties;
  Map<String, dynamic> toMap();
}

/// Typed Lazy Pointer for Cross-Entity References.
typedef EntityRef<T extends DomainEntity> = EntityReference<T>;

@immutable
class EntityReference<T extends DomainEntity> {
  final EntityType refType;
  final String slug;
  final RulesetVersion? rulesetPreferred;
  final String displayName;

  const EntityReference({
    required this.refType,
    required this.slug,
    required this.displayName,
    this.rulesetPreferred,
  });

  Map<String, dynamic> toMap() => {
        'refType': refType.name,
        'slug': slug,
        'rulesetPreferred': rulesetPreferred?.name,
        'displayName': displayName,
      };

  factory EntityReference.fromMap(Map<String, dynamic> map) {
    final refTypeStr = map['refType']?.toString() ?? 'spell';
    final refType = EntityType.values.firstWhere(
      (e) => e.name == refTypeStr,
      orElse: () => EntityType.spell,
    );

    RulesetVersion? ruleset;
    if (map['rulesetPreferred'] != null) {
      final rStr = map['rulesetPreferred'].toString();
      ruleset = RulesetVersion.values.firstWhere(
        (r) => r.name == rStr,
        orElse: () => RulesetVersion.homebrew,
      );
    }

    return EntityReference<T>(
      refType: refType,
      slug: map['slug']?.toString() ?? '',
      displayName: map['displayName']?.toString() ?? map['slug']?.toString() ?? '',
      rulesetPreferred: ruleset,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EntityReference<T> &&
          runtimeType == other.runtimeType &&
          refType == other.refType &&
          slug == other.slug &&
          rulesetPreferred == other.rulesetPreferred &&
          displayName == other.displayName;

  @override
  int get hashCode =>
      refType.hashCode ^
      slug.hashCode ^
      rulesetPreferred.hashCode ^
      displayName.hashCode;

  @override
  String toString() => 'Ref<$refType>($slug, pref: $rulesetPreferred)';
}

/// Null-Object Stub returned when a pointer cannot be resolved in the active stack.
class UnresolvedReference implements DomainEntity {
  @override
  final EntityId id;
  @override
  final String name;
  @override
  final EntityType entityType;
  final String reason;
  @override
  final Map<String, dynamic> customProperties;

  UnresolvedReference({
    required String slug,
    required this.entityType,
    this.reason = 'Entity not found in active priority stack',
    this.customProperties = const {},
  })  : id = EntityId(slug: slug, ruleset: RulesetVersion.homebrew),
        name = '[Missing ${entityType.name}: $slug]';

  @override
  RulesetVersion get ruleset => id.ruleset;
  @override
  String get slug => id.slug;

  @override
  Map<String, dynamic> toMap() => {
        'id': id.toMap(),
        'name': name,
        'entityType': entityType.name,
        'reason': reason,
        'customProperties': customProperties,
      };
}

/// Strongly typed result container for dynamic reference resolution.
@immutable
class ResolutionResult<T extends DomainEntity> {
  final T? entity;
  final UnresolvedReference? unresolved;

  const ResolutionResult.success(T this.entity) : unresolved = null;
  const ResolutionResult.missing(UnresolvedReference this.unresolved) : entity = null;

  bool get isResolved => entity != null;
  String get displayName => isResolved ? entity!.name : unresolved!.name;
  DomainEntity get value => isResolved ? entity! : unresolved!;
}
