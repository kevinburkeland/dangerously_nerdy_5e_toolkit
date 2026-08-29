import 'package:flutter/foundation.dart';

/// Supported Ruleset Baselines
enum RulesetVersion {
  v2014, // 5e SRD 2014 / PHB
  v2024, // 5e SRD 2024 / XPHB
  homebrew,
}

/// Domain Entity Classification
enum EntityType {
  spell,
  monster,
  equipment,
  feat,
  classFeature,
  custom,
}

/// Standardized Action Types for activation economy
enum ActionType {
  action,
  bonusAction,
  reaction,
  minute,
  hour,
  special,
}

/// Standardized Duration Types
enum DurationType {
  instantaneous,
  rounds,
  timed,
  permanent,
  special,
}

/// Standardized 5e Damage Types
enum DamageType {
  acid,
  bludgeoning,
  cold,
  fire,
  force,
  lightning,
  necrotic,
  piercing,
  poison,
  psychic,
  radiant,
  slashing,
  thunder,
  untyped,
}

/// Composite Entity Identifier supporting multi-ruleset coexistence.
@immutable
class EntityId {
  final String slug;
  final RulesetVersion ruleset;

  const EntityId({
    required this.slug,
    required this.ruleset,
  });

  Map<String, dynamic> toMap() => {
        'slug': slug,
        'ruleset': ruleset.name,
      };

  factory EntityId.fromMap(Map<String, dynamic> map) {
    final rulesetStr = map['ruleset']?.toString() ?? 'homebrew';
    final ruleset = RulesetVersion.values.firstWhere(
      (r) => r.name == rulesetStr,
      orElse: () => RulesetVersion.homebrew,
    );
    return EntityId(
      slug: map['slug']?.toString() ?? '',
      ruleset: ruleset,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EntityId &&
          runtimeType == other.runtimeType &&
          slug == other.slug &&
          ruleset == other.ruleset;

  @override
  int get hashCode => slug.hashCode ^ ruleset.hashCode;

  @override
  String toString() => '$slug@${ruleset.name}';
}
