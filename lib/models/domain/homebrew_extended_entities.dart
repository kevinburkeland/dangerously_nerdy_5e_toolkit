import 'package:flutter/foundation.dart';
import '../dm_screen_data.dart';
import 'character_models.dart' show AbilityType;
import 'core_types.dart';
import 'entity_reference.dart';
import 'feature_grant.dart';

/// Types of class decision points encountered during character creation and progression.
enum FeatureChoiceType {
  subclassSelection,
  fightingStyle,
  invocations,
  infusions,
  metamagic,
  primalOrder,
  divineOrder,
  expertise,
  languageOrTool,
  pactBoon,
  customOption;

  String get displayName {
    switch (this) {
      case FeatureChoiceType.subclassSelection:
        return 'Subclass / Archetype';
      case FeatureChoiceType.fightingStyle:
        return 'Fighting Style';
      case FeatureChoiceType.invocations:
        return 'Eldritch Invocations';
      case FeatureChoiceType.infusions:
        return 'Infusions';
      case FeatureChoiceType.metamagic:
        return 'Metamagic';
      case FeatureChoiceType.primalOrder:
        return 'Primal Order';
      case FeatureChoiceType.divineOrder:
        return 'Divine Order';
      case FeatureChoiceType.expertise:
        return 'Expertise';
      case FeatureChoiceType.languageOrTool:
        return 'Language / Tool';
      case FeatureChoiceType.pactBoon:
        return 'Pact Boon';
      case FeatureChoiceType.customOption:
        return 'Special Option';
    }
  }
}

/// A specific selectable option within a [ClassFeatureDecision].
@immutable
class FeatureOption {
  final String id;
  final String name;
  final String descriptionMarkdown;
  final Map<String, dynamic> grants; // e.g. {'acBonus': 1, 'bonusSpells': [...], 'proficiencies': [...]}
  final Map<String, dynamic> customProperties;

  const FeatureOption({
    required this.id,
    required this.name,
    required this.descriptionMarkdown,
    this.grants = const {},
    this.customProperties = const {},
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'descriptionMarkdown': descriptionMarkdown,
        'grants': grants,
        'customProperties': customProperties,
      };

  factory FeatureOption.fromMap(Map<String, dynamic> map) {
    return FeatureOption(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      descriptionMarkdown: map['descriptionMarkdown']?.toString() ?? '',
      grants: Map<String, dynamic>.from(map['grants'] as Map? ?? {}),
      customProperties: Map<String, dynamic>.from(map['customProperties'] as Map? ?? {}),
    );
  }
}

/// Declarative schema defining a decision point / choice requirement at a specific class level.
@immutable
class ClassFeatureDecision {
  final String id;
  final String name;
  final String prompt;
  final int levelRequired;
  final FeatureChoiceType type;
  final int minSelections;
  final int maxSelections;
  final List<FeatureOption> availableOptions;
  final RulesetVersion? ruleset;
  final Map<String, dynamic> customProperties;

  const ClassFeatureDecision({
    required this.id,
    required this.name,
    required this.prompt,
    required this.levelRequired,
    required this.type,
    this.minSelections = 1,
    this.maxSelections = 1,
    this.availableOptions = const [],
    this.ruleset,
    this.customProperties = const {},
  });

  bool isValidSelection(List<String> selectedIds) {
    return selectedIds.length >= minSelections && selectedIds.length <= maxSelections;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'prompt': prompt,
        'levelRequired': levelRequired,
        'type': type.name,
        'minSelections': minSelections,
        'maxSelections': maxSelections,
        'availableOptions': availableOptions.map((o) => o.toMap()).toList(),
        if (ruleset != null) 'ruleset': ruleset!.name,
        'customProperties': customProperties,
      };

  factory ClassFeatureDecision.fromMap(Map<String, dynamic> map) {
    final typeName = map['type']?.toString();
    final type = FeatureChoiceType.values.firstWhere(
      (t) => t.name == typeName,
      orElse: () => FeatureChoiceType.customOption,
    );
    final rulesetName = map['ruleset']?.toString();
    final ruleset = rulesetName != null
        ? RulesetVersion.values.firstWhere(
            (r) => r.name == rulesetName,
            orElse: () => RulesetVersion.v2024,
          )
        : null;

    return ClassFeatureDecision(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      prompt: map['prompt']?.toString() ?? '',
      levelRequired: (map['levelRequired'] as num?)?.toInt() ?? 1,
      type: type,
      minSelections: (map['minSelections'] as num?)?.toInt() ?? 1,
      maxSelections: (map['maxSelections'] as num?)?.toInt() ?? 1,
      availableOptions: (map['availableOptions'] as List? ?? [])
          .whereType<Map>()
          .map((o) => FeatureOption.fromMap(Map<String, dynamic>.from(o)))
          .toList(),
      ruleset: ruleset,
      customProperties: Map<String, dynamic>.from(map['customProperties'] as Map? ?? {}),
    );
  }
}

/// A comprehensive class definition entity supporting dual-ruleset progression and custom extensions.
@immutable
class CharacterClass extends DomainEntity {
  @override
  final EntityId id;
  @override
  final String name;
  final String hitDie;
  final String? primaryAbility;
  final List<String> savingThrows;
  final List<String> armorProficiencies;
  final List<String> weaponProficiencies;
  final String? spellcastingAbility;
  final String featuresMarkdown;
  final List<Subclass> subclasses;
  final int subclassSelectionLevel;
  final List<ClassFeatureDecision> featureDecisions;
  final List<FeatureGrant> grants;
  @override
  final Map<String, dynamic> customProperties;

  const CharacterClass({
    required this.id,
    required this.name,
    required this.hitDie,
    this.primaryAbility,
    this.savingThrows = const [],
    this.armorProficiencies = const [],
    this.weaponProficiencies = const [],
    this.spellcastingAbility,
    this.featuresMarkdown = '',
    this.subclasses = const [],
    this.subclassSelectionLevel = 3,
    this.featureDecisions = const [],
    this.grants = const [],
    this.customProperties = const {},
  });

  @override
  EntityType get entityType => EntityType.classDefinition;

  /// Returns the required level for selecting a subclass archetype under [ruleset].
  int getSubclassLevel([RulesetVersion? ruleset]) {
    final activeRuleset = ruleset ?? id.ruleset;
    if (activeRuleset == RulesetVersion.v2014) {
      final slug = id.slug.toLowerCase();
      if (['cleric', 'sorcerer', 'warlock'].contains(slug)) return 1;
      if (['druid', 'wizard'].contains(slug)) return 2;
      return 3;
    }
    return subclassSelectionLevel;
  }

  /// Returns all feature decisions configured for [level], optionally filtered by [ruleset].
  List<ClassFeatureDecision> getDecisionsForLevel(int level, {RulesetVersion? ruleset}) {
    return featureDecisions.where((d) {
      if (d.levelRequired != level) return false;
      if (ruleset != null && d.ruleset != null && d.ruleset != ruleset && d.ruleset != RulesetVersion.homebrew) {
        return false;
      }
      return true;
    }).toList();
  }

  /// Finds a specific feature decision by its unique identifier.
  ClassFeatureDecision? getDecision(String decisionId) {
    return featureDecisions.where((d) => d.id == decisionId).firstOrNull;
  }

  @override
  Map<String, dynamic> toMap() => {
        'id': id.toMap(),
        'name': name,
        'hitDie': hitDie,
        'primaryAbility': primaryAbility,
        'savingThrows': savingThrows,
        'armorProficiencies': armorProficiencies,
        'weaponProficiencies': weaponProficiencies,
        'spellcastingAbility': spellcastingAbility,
        'featuresMarkdown': featuresMarkdown,
        'subclasses': subclasses.map((s) => s.toMap()).toList(),
        'subclassSelectionLevel': subclassSelectionLevel,
        'featureDecisions': featureDecisions.map((f) => f.toMap()).toList(),
        'grants': grants.map((g) => g.toMap()).toList(),
        'customProperties': customProperties,
      };

  factory CharacterClass.fromMap(Map<String, dynamic> map) {
    final customProperties =
        Map<String, dynamic>.from(map['customProperties'] as Map? ?? {});
    var grants = (map['grants'] as List? ?? [])
        .whereType<Map>()
        .map((g) => FeatureGrant.fromMap(Map<String, dynamic>.from(g)))
        .toList();

    if (grants.isEmpty) {
      final addSpells = customProperties['additionalSpells'] ??
          customProperties['spells'] ??
          map['additionalSpells'] ??
          map['spells'];
      if (addSpells != null) {
        final slug = map['id'] is Map ? (map['id']['slug']?.toString() ?? '') : '';
        grants = FeatureGrant.extractBonusSpells(addSpells, 'class', slug);
      }
    }

    return CharacterClass(
      id: EntityId.fromMap(Map<String, dynamic>.from(map['id'] as Map? ?? {})),
      name: map['name']?.toString() ?? '',
      hitDie: map['hitDie']?.toString() ?? 'd8',
      primaryAbility: map['primaryAbility']?.toString(),
      savingThrows: (map['savingThrows'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
      armorProficiencies: (map['armorProficiencies'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
      weaponProficiencies: (map['weaponProficiencies'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
      spellcastingAbility: map['spellcastingAbility']?.toString(),
      featuresMarkdown: map['featuresMarkdown']?.toString() ?? '',
      subclasses: (map['subclasses'] as List? ?? [])
          .whereType<Map>()
          .map((e) => Subclass.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      subclassSelectionLevel: (map['subclassSelectionLevel'] as num?)?.toInt() ?? 3,
      featureDecisions: (map['featureDecisions'] as List? ?? [])
          .whereType<Map>()
          .map((d) => ClassFeatureDecision.fromMap(Map<String, dynamic>.from(d)))
          .toList(),
      grants: grants,
      customProperties: customProperties,
    );
  }

  CharacterClass copyWith({
    EntityId? id,
    String? name,
    String? hitDie,
    String? primaryAbility,
    List<String>? savingThrows,
    List<String>? armorProficiencies,
    List<String>? weaponProficiencies,
    String? spellcastingAbility,
    String? featuresMarkdown,
    List<Subclass>? subclasses,
    int? subclassSelectionLevel,
    List<ClassFeatureDecision>? featureDecisions,
    List<FeatureGrant>? grants,
    Map<String, dynamic>? customProperties,
  }) {
    return CharacterClass(
      id: id ?? this.id,
      name: name ?? this.name,
      hitDie: hitDie ?? this.hitDie,
      primaryAbility: primaryAbility ?? this.primaryAbility,
      savingThrows: savingThrows ?? this.savingThrows,
      armorProficiencies: armorProficiencies ?? this.armorProficiencies,
      weaponProficiencies: weaponProficiencies ?? this.weaponProficiencies,
      spellcastingAbility: spellcastingAbility ?? this.spellcastingAbility,
      featuresMarkdown: featuresMarkdown ?? this.featuresMarkdown,
      subclasses: subclasses ?? this.subclasses,
      subclassSelectionLevel: subclassSelectionLevel ?? this.subclassSelectionLevel,
      featureDecisions: featureDecisions ?? this.featureDecisions,
      grants: grants ?? this.grants,
      customProperties: customProperties ?? this.customProperties,
    );
  }
}

/// Subclass archetype option associated with a parent class.
@immutable
class Subclass extends DomainEntity {
  @override
  final EntityId id;
  @override
  final String name;
  final String classSlug;
  final String shortName;
  final String featuresMarkdown;
  /// Declarative mechanic grants emitted by this subclass archetype.
  final List<FeatureGrant> grants;
  @override
  final Map<String, dynamic> customProperties;

  const Subclass({
    required this.id,
    required this.name,
    required this.classSlug,
    String? shortName,
    required this.featuresMarkdown,
    this.grants = const [],
    this.customProperties = const {},
  }) : shortName = shortName ?? name;

  @override
  EntityType get entityType => EntityType.subclass;

  @override
  Map<String, dynamic> toMap() => {
        'id': id.toMap(),
        'name': name,
        'classSlug': classSlug,
        'shortName': shortName,
        'featuresMarkdown': featuresMarkdown,
        'grants': grants.map((g) => g.toMap()).toList(),
        'customProperties': customProperties,
      };

  factory Subclass.fromMap(Map<String, dynamic> map) {
    final customProperties =
        Map<String, dynamic>.from(map['customProperties'] as Map? ?? {});
    var grants = (map['grants'] as List? ?? [])
        .whereType<Map>()
        .map((g) => FeatureGrant.fromMap(Map<String, dynamic>.from(g)))
        .toList();

    if (grants.isEmpty) {
      final addSpells = customProperties['additionalSpells'] ??
          customProperties['subclassSpells'] ??
          map['additionalSpells'] ??
          map['subclassSpells'];
      if (addSpells != null) {
        final slug = map['id'] is Map ? (map['id']['slug']?.toString() ?? '') : '';
        grants = FeatureGrant.extractBonusSpells(addSpells, 'subclass', slug);
      }
    }

    return Subclass(
      id: EntityId.fromMap(Map<String, dynamic>.from(map['id'] as Map? ?? {})),
      name: map['name']?.toString() ?? '',
      classSlug: map['classSlug']?.toString() ?? '',
      shortName: map['shortName']?.toString() ?? map['name']?.toString() ?? '',
      featuresMarkdown: map['featuresMarkdown']?.toString() ?? '',
      grants: grants,
      customProperties: customProperties,
    );
  }

  Subclass copyWith({
    EntityId? id,
    String? name,
    String? classSlug,
    String? shortName,
    String? featuresMarkdown,
    List<FeatureGrant>? grants,
    Map<String, dynamic>? customProperties,
  }) {
    return Subclass(
      id: id ?? this.id,
      name: name ?? this.name,
      classSlug: classSlug ?? this.classSlug,
      shortName: shortName ?? this.shortName,
      featuresMarkdown: featuresMarkdown ?? this.featuresMarkdown,
      grants: grants ?? this.grants,
      customProperties: customProperties ?? this.customProperties,
    );
  }
}

/// Race, Species, or Lineage definition in 5e.
@immutable
class Race extends DomainEntity {
  @override
  final EntityId id;
  @override
  final String name;
  final String size;
  final String speed;
  final String? abilityScoreSummary;
  final String traitsMarkdown;
  final List<Subrace> subraces;
  final int bonusFeatCount;
  final int flexibleAbilityCount;
  final int flexibleAbilityBonus;
  final Map<String, int> fixedAbilityBonuses;
  /// Declarative mechanic grants emitted by this species (e.g., darkvision, skill proficiency).
  final List<FeatureGrant> grants;
  @override
  final Map<String, dynamic> customProperties;

  Race({
    required this.id,
    required this.name,
    this.size = 'Medium',
    this.speed = '30 ft.',
    this.abilityScoreSummary,
    required this.traitsMarkdown,
    this.subraces = const [],
    int? bonusFeatCount,
    int? flexibleAbilityCount,
    int? flexibleAbilityBonus,
    Map<String, int>? fixedAbilityBonuses,
    this.grants = const [],
    this.customProperties = const {},
  })  : bonusFeatCount = bonusFeatCount ?? _resolveBonusFeatCount(id.slug, customProperties),
        flexibleAbilityCount = flexibleAbilityCount ?? _resolveFlexibleAbilityCount(id.slug, customProperties),
        flexibleAbilityBonus = flexibleAbilityBonus ?? _resolveFlexibleAbilityBonus(id.slug, customProperties),
        fixedAbilityBonuses = fixedAbilityBonuses ?? _resolveFixedAbilityBonuses(id.slug, customProperties);

  static int _resolveBonusFeatCount(String slug, Map<String, dynamic> custom) {
    if (slug == 'human-variant' || slug == 'custom-lineage') return 1;
    if (custom['isVariantHuman'] == true || custom['isCustomLineage'] == true) return 1;
    final featCount = custom['bonusFeatCount'];
    if (featCount is num && featCount > 0) return featCount.toInt();
    return 0;
  }

  static int _resolveFlexibleAbilityCount(String slug, Map<String, dynamic> custom) {
    if (custom['abilityChoiceCount'] is num) return (custom['abilityChoiceCount'] as num).toInt();
    if (custom['flexibleAbilityCount'] is num) return (custom['flexibleAbilityCount'] as num).toInt();
    if (slug == 'human-variant' || custom['isVariantHuman'] == true) return 2;
    if (slug == 'custom-lineage' || custom['isCustomLineage'] == true) return 1;
    return 0;
  }

  static int _resolveFlexibleAbilityBonus(String slug, Map<String, dynamic> custom) {
    if (custom['abilityChoiceBonus'] is num) return (custom['abilityChoiceBonus'] as num).toInt();
    if (custom['flexibleAbilityBonus'] is num) return (custom['flexibleAbilityBonus'] as num).toInt();
    if (slug == 'custom-lineage' || custom['isCustomLineage'] == true) return 2;
    return 1;
  }

  static Map<String, int> _resolveFixedAbilityBonuses(String slug, Map<String, dynamic> custom) {
    final raw = custom['abilityBonuses2014'] ?? custom['abilityBonuses'];
    if (raw is Map) {
      final result = <String, int>{};
      raw.forEach((k, v) {
        if (v is num) {
          result[k.toString().toLowerCase()] = v.toInt();
        }
      });
      return result;
    }
    if (slug == 'human') {
      return const {
        'strength': 1,
        'dexterity': 1,
        'constitution': 1,
        'intelligence': 1,
        'wisdom': 1,
        'charisma': 1,
      };
    }
    return const {};
  }

  @override
  EntityType get entityType => EntityType.species;

  /// Returns whether this race / lineage grants a starting bonus feat in 2014 (e.g. Variant Human, Custom Lineage, or homebrew).
  bool get grantsBonusFeat => bonusFeatCount > 0;

  /// Number of flexible ability score increases player can choose (e.g. 2 for Variant Human, 1 for Custom Lineage).
  int get flexibleAbilityChoiceCount => flexibleAbilityCount;

  /// The bonus value added to each chosen flexible ability score (default 1, or 2 for Custom Lineage).
  int get flexibleAbilityBonusValue => flexibleAbilityBonus;

  /// Fixed ability score bonuses granted in 2014 rules (e.g. +2 DEX for Elf, +2 CON for Dwarf, +1 to all for Human).
  Map<String, int> get fixedAbilityBonuses2014 => fixedAbilityBonuses;

  /// Returns the base movement speed formatted for the selected rules edition.
  String getSpeedForEdition(DmRulesEdition edition) {
    if (edition == DmRulesEdition.v2014) {
      if (id.slug == 'dwarf' || id.slug == 'gnome' || id.slug == 'halfling') {
        return '25 ft.';
      }
      if (id.slug == 'goliath') {
        return '30 ft.';
      }
    } else {
      if (id.slug == 'goliath') {
        return '35 ft.';
      }
    }
    return speed;
  }

  @override
  Map<String, dynamic> toMap() => {
        'id': id.toMap(),
        'name': name,
        'size': size,
        'speed': speed,
        'abilityScoreSummary': abilityScoreSummary,
        'traitsMarkdown': traitsMarkdown,
        'subraces': subraces.map((s) => s.toMap()).toList(),
        'bonusFeatCount': bonusFeatCount,
        'flexibleAbilityCount': flexibleAbilityCount,
        'flexibleAbilityBonus': flexibleAbilityBonus,
        'fixedAbilityBonuses': fixedAbilityBonuses,
        'grants': grants.map((g) => g.toMap()).toList(),
        'customProperties': customProperties,
      };

  factory Race.fromMap(Map<String, dynamic> map) {
    final custom = Map<String, dynamic>.from(map['customProperties'] as Map? ?? {});
    return Race(
      id: EntityId.fromMap(Map<String, dynamic>.from(map['id'] as Map? ?? {})),
      name: map['name']?.toString() ?? '',
      size: map['size']?.toString() ?? 'Medium',
      speed: map['speed']?.toString() ?? '30 ft.',
      abilityScoreSummary: map['abilityScoreSummary']?.toString(),
      traitsMarkdown: map['traitsMarkdown']?.toString() ?? '',
      subraces: (map['subraces'] as List? ?? [])
          .whereType<Map>()
          .map((e) => Subrace.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      bonusFeatCount: (map['bonusFeatCount'] as num?)?.toInt(),
      flexibleAbilityCount: (map['flexibleAbilityCount'] as num?)?.toInt(),
      flexibleAbilityBonus: (map['flexibleAbilityBonus'] as num?)?.toInt(),
      fixedAbilityBonuses: map['fixedAbilityBonuses'] is Map
          ? (map['fixedAbilityBonuses'] as Map).map((k, v) => MapEntry(k.toString(), (v as num).toInt()))
          : null,
      grants: (map['grants'] as List? ?? [])
          .whereType<Map>()
          .map((g) => FeatureGrant.fromMap(Map<String, dynamic>.from(g)))
          .toList(),
      customProperties: custom,
    );
  }

  Race copyWith({
    EntityId? id,
    String? name,
    String? size,
    String? speed,
    String? abilityScoreSummary,
    String? traitsMarkdown,
    List<Subrace>? subraces,
    int? bonusFeatCount,
    int? flexibleAbilityCount,
    int? flexibleAbilityBonus,
    Map<String, int>? fixedAbilityBonuses,
    List<FeatureGrant>? grants,
    Map<String, dynamic>? customProperties,
  }) {
    return Race(
      id: id ?? this.id,
      name: name ?? this.name,
      size: size ?? this.size,
      speed: speed ?? this.speed,
      abilityScoreSummary: abilityScoreSummary ?? this.abilityScoreSummary,
      traitsMarkdown: traitsMarkdown ?? this.traitsMarkdown,
      subraces: subraces ?? this.subraces,
      bonusFeatCount: bonusFeatCount ?? this.bonusFeatCount,
      flexibleAbilityCount: flexibleAbilityCount ?? this.flexibleAbilityCount,
      flexibleAbilityBonus: flexibleAbilityBonus ?? this.flexibleAbilityBonus,
      fixedAbilityBonuses: fixedAbilityBonuses ?? this.fixedAbilityBonuses,
      grants: grants ?? this.grants,
      customProperties: customProperties ?? this.customProperties,
    );
  }
}

/// Subrace or variant lineage variant.
@immutable
class Subrace extends DomainEntity {
  @override
  final EntityId id;
  @override
  final String name;
  final String raceSlug;
  final String traitsMarkdown;
  @override
  final Map<String, dynamic> customProperties;

  const Subrace({
    required this.id,
    required this.name,
    required this.raceSlug,
    required this.traitsMarkdown,
    this.customProperties = const {},
  });

  @override
  EntityType get entityType => EntityType.species;

  @override
  Map<String, dynamic> toMap() => {
        'id': id.toMap(),
        'name': name,
        'raceSlug': raceSlug,
        'traitsMarkdown': traitsMarkdown,
        'customProperties': customProperties,
      };

  factory Subrace.fromMap(Map<String, dynamic> map) {
    return Subrace(
      id: EntityId.fromMap(Map<String, dynamic>.from(map['id'] as Map? ?? {})),
      name: map['name']?.toString() ?? '',
      raceSlug: map['raceSlug']?.toString() ?? '',
      traitsMarkdown: map['traitsMarkdown']?.toString() ?? '',
      customProperties:
          Map<String, dynamic>.from(map['customProperties'] as Map? ?? {}),
    );
  }
}

/// Feat or character customization option.
@immutable
class Feat extends DomainEntity {
  @override
  final EntityId id;
  @override
  final String name;
  final String? prerequisite;
  final String category; // e.g. "Origin", "General", "Fighting Style", "Epic Boon"
  final String descriptionMarkdown;
  /// Declarative mechanic grants emitted by this feat (e.g., HP bonus, initiative bonus).
  final List<FeatureGrant> grants;
  @override
  final Map<String, dynamic> customProperties;

  const Feat({
    required this.id,
    required this.name,
    this.prerequisite,
    this.category = 'General',
    required this.descriptionMarkdown,
    this.grants = const [],
    this.customProperties = const {},
  });

  @override
  EntityType get entityType => EntityType.feat;

  @override
  Map<String, dynamic> toMap() => {
        'id': id.toMap(),
        'name': name,
        'prerequisite': prerequisite,
        'category': category,
        'descriptionMarkdown': descriptionMarkdown,
        'grants': grants.map((g) => g.toMap()).toList(),
        'customProperties': customProperties,
      };

  factory Feat.fromMap(Map<String, dynamic> map) {
    final customProperties =
        Map<String, dynamic>.from(map['customProperties'] as Map? ?? {});

    // Ensure selectableAbilities and statIncreaseAmount are hydrated if ability is present
    final rawAbility = customProperties['ability'] ??
        customProperties['abilities'] ??
        map['ability'];
    if (rawAbility != null &&
        (customProperties['selectableAbilities'] == null ||
            (customProperties['selectableAbilities'] is List &&
                (customProperties['selectableAbilities'] as List).isEmpty))) {
      final parsed = FeatAsiExtension.parseFeatAbilityData(rawAbility);
      if (parsed.selectableAbilities.isNotEmpty) {
        customProperties['selectableAbilities'] =
            parsed.selectableAbilities.map((a) => a.name).toList();
        customProperties['statIncreaseAmount'] = parsed.amount;
        if (parsed.selectableAbilities.length == 1) {
          customProperties['statIncreaseAbility'] =
              parsed.selectableAbilities.first.name;
        }
      }
    }

    return Feat(
      id: EntityId.fromMap(Map<String, dynamic>.from(map['id'] as Map? ?? {})),
      name: map['name']?.toString() ?? '',
      prerequisite: map['prerequisite']?.toString(),
      category: map['category']?.toString() ?? 'General',
      descriptionMarkdown: map['descriptionMarkdown']?.toString() ?? '',
      grants: (map['grants'] as List? ?? [])
          .whereType<Map>()
          .map((g) => FeatureGrant.fromMap(Map<String, dynamic>.from(g)))
          .toList(),
      customProperties: customProperties,
    );
  }

  Feat copyWith({
    EntityId? id,
    String? name,
    String? prerequisite,
    String? category,
    String? descriptionMarkdown,
    List<FeatureGrant>? grants,
    Map<String, dynamic>? customProperties,
  }) {
    return Feat(
      id: id ?? this.id,
      name: name ?? this.name,
      prerequisite: prerequisite ?? this.prerequisite,
      category: category ?? this.category,
      descriptionMarkdown: descriptionMarkdown ?? this.descriptionMarkdown,
      grants: grants ?? this.grants,
      customProperties: customProperties ?? this.customProperties,
    );
  }
}

/// Convenience extension for querying ability score improvements, choices,
/// and associated riders (like saving throw proficiencies) on a [Feat].
extension FeatAsiExtension on Feat {
  /// Whether this feat provides any ability score increase (fixed or user choice).
  bool get hasAbilityScoreIncrease => selectableAbilities.isNotEmpty;

  /// Whether this feat requires the user to choose an ability score from multiple options.
  bool get requiresAbilityChoice => selectableAbilities.length > 1;

  /// Helper to parse structured ability data from 5e compendium formats
  static ({List<AbilityType> selectableAbilities, int amount}) parseFeatAbilityData(dynamic rawAbility) {
    final abilities = <AbilityType>[];
    int amount = 1;

    void processMap(Map map) {
      map.forEach((k, v) {
        final key = k.toString().toLowerCase().trim();
        if (['str', 'dex', 'con', 'int', 'wis', 'cha', 'strength', 'dexterity', 'constitution', 'intelligence', 'wisdom', 'charisma'].contains(key)) {
          final parsed = AbilityType.fromLooseString(key);
          if (!abilities.contains(parsed)) abilities.add(parsed);
          if (v is num && v.toInt() > 0) amount = v.toInt();
        } else if (key == 'choose' && v is Map) {
          if (v['from'] is List) {
            for (final item in v['from']) {
              final parsed = AbilityType.fromLooseString(item.toString());
              if (!abilities.contains(parsed)) abilities.add(parsed);
            }
          }
          if (v['amount'] is num && (v['amount'] as num).toInt() > 0) {
            amount = (v['amount'] as num).toInt();
          }
        }
      });
    }

    if (rawAbility is List) {
      for (final item in rawAbility) {
        if (item is Map) {
          processMap(item);
        } else if (item is String) {
          final parsed = AbilityType.fromLooseString(item);
          if (!abilities.contains(parsed)) abilities.add(parsed);
        }
      }
    } else if (rawAbility is Map) {
      processMap(rawAbility);
    } else if (rawAbility is String && rawAbility.trim().isNotEmpty) {
      final parsed = AbilityType.fromLooseString(rawAbility);
      abilities.add(parsed);
    }

    return (selectableAbilities: abilities, amount: amount);
  }

  /// List of ability types the user can choose from (or single ability if fixed).
  List<AbilityType> get selectableAbilities {
    // 1. Explicit list in customProperties
    final rawList = customProperties['selectableAbilities'] ?? customProperties['statChoicePool'];
    if (rawList is List && rawList.isNotEmpty) {
      final list = <AbilityType>[];
      for (final item in rawList) {
        final parsed = AbilityType.fromLooseString(item.toString());
        if (!list.contains(parsed)) list.add(parsed);
      }
      if (list.isNotEmpty) return list;
    }

    // 2. Structured ability in customProperties (maps, choose blocks, or single string)
    final rawAbility = customProperties['ability'] ??
        customProperties['abilities'] ??
        customProperties['statIncreaseAbility'];
    if (rawAbility != null) {
      final parsed = parseFeatAbilityData(rawAbility);
      if (parsed.selectableAbilities.isNotEmpty) {
        return parsed.selectableAbilities;
      }
    }

    // 3. Fallback to slug-based defaults for standard SRD / known feats if not explicitly declared
    return switch (id.slug.toLowerCase()) {
      'chef' => const [AbilityType.constitution, AbilityType.wisdom],
      'crusher' => const [AbilityType.strength, AbilityType.constitution],
      'slasher' => const [AbilityType.strength, AbilityType.dexterity],
      'piercer' => const [AbilityType.strength, AbilityType.dexterity],
      'fey-touched' => const [AbilityType.intelligence, AbilityType.wisdom, AbilityType.charisma],
      'shadow-touched' => const [AbilityType.intelligence, AbilityType.wisdom, AbilityType.charisma],
      'telekinetic' => const [AbilityType.intelligence, AbilityType.wisdom, AbilityType.charisma],
      'telepathic' => const [AbilityType.intelligence, AbilityType.wisdom, AbilityType.charisma],
      'skill-expert' => AbilityType.values,
      'elven-accuracy' => const [AbilityType.dexterity, AbilityType.intelligence, AbilityType.wisdom, AbilityType.charisma],
      'resilient' => AbilityType.values,
      'athlete' => const [AbilityType.strength, AbilityType.dexterity],
      'observant' => const [AbilityType.intelligence, AbilityType.wisdom],
      'actor' => const [AbilityType.charisma],
      'heavy-armor-master' => const [AbilityType.strength],
      'durable' => const [AbilityType.constitution],
      'keen-mind' => const [AbilityType.intelligence],
      'war-caster' when id.ruleset == RulesetVersion.v2024 => const [
          AbilityType.intelligence,
          AbilityType.wisdom,
          AbilityType.charisma,
        ],
      'great-weapon-master' when id.ruleset == RulesetVersion.v2024 => const [
          AbilityType.strength,
        ],
      'sharpshooter' when id.ruleset == RulesetVersion.v2024 => const [
          AbilityType.dexterity,
        ],
      'sentinel' when id.ruleset == RulesetVersion.v2024 => const [
          AbilityType.strength,
          AbilityType.dexterity,
        ],
      'polearm-master' when id.ruleset == RulesetVersion.v2024 => const [
          AbilityType.strength,
          AbilityType.dexterity,
        ],
      'shield-master' when id.ruleset == RulesetVersion.v2024 => const [
          AbilityType.strength,
        ],
      'dual-wielder' when id.ruleset == RulesetVersion.v2024 => const [
          AbilityType.strength,
          AbilityType.dexterity,
        ],
      'grappler' when id.ruleset == RulesetVersion.v2024 => const [
          AbilityType.strength,
          AbilityType.dexterity,
        ],
      'crossbow-expert' when id.ruleset == RulesetVersion.v2024 => const [
          AbilityType.dexterity,
        ],
      'defensive-duelist' when id.ruleset == RulesetVersion.v2024 => const [
          AbilityType.dexterity,
        ],
      'elemental-adept' when id.ruleset == RulesetVersion.v2024 => const [
          AbilityType.intelligence,
          AbilityType.wisdom,
          AbilityType.charisma,
        ],
      'inspiring-leader' when id.ruleset == RulesetVersion.v2024 => const [
          AbilityType.wisdom,
          AbilityType.charisma,
        ],
      'mage-slayer' when id.ruleset == RulesetVersion.v2024 => const [
          AbilityType.strength,
          AbilityType.dexterity,
        ],
      'medium-armor-master' when id.ruleset == RulesetVersion.v2024 => const [
          AbilityType.strength,
          AbilityType.dexterity,
        ],
      'mounted-combatant' when id.ruleset == RulesetVersion.v2024 => const [
          AbilityType.strength,
          AbilityType.dexterity,
          AbilityType.wisdom,
        ],
      'ritual-caster' when id.ruleset == RulesetVersion.v2024 => const [
          AbilityType.intelligence,
          AbilityType.wisdom,
          AbilityType.charisma,
        ],
      'spell-sniper' when id.ruleset == RulesetVersion.v2024 => const [
          AbilityType.intelligence,
          AbilityType.wisdom,
          AbilityType.charisma,
        ],
      _ => const [],
    };
  }

  /// Amount to increase the chosen or fixed ability score (defaults to 1).
  int get statIncreaseAmount {
    if (customProperties['statIncrease'] is num) {
      return (customProperties['statIncrease'] as num).toInt();
    }
    if (customProperties['statIncreaseAmount'] is num) {
      return (customProperties['statIncreaseAmount'] as num).toInt();
    }
    final rawAbility = customProperties['ability'] ?? customProperties['abilities'];
    if (rawAbility != null) {
      final parsed = parseFeatAbilityData(rawAbility);
      if (parsed.amount > 0) return parsed.amount;
    }
    return selectableAbilities.isNotEmpty ? 1 : 0;
  }

  /// Whether this feat grants saving throw proficiency in the chosen ability (e.g. Resilient).
  bool get grantsSavingThrowProficiency {
    if (customProperties['grantsSavingThrowProficiency'] == true) return true;
    return id.slug.toLowerCase() == 'resilient';
  }

  /// Human-readable explanation of any choice rider attached to this feat.
  String? get choiceRiderDescription {
    if (grantsSavingThrowProficiency) {
      return 'Grants proficiency in saving throws using the chosen ability.';
    }
    final rawDesc = customProperties['riderDescription']?.toString();
    if (rawDesc != null && rawDesc.isNotEmpty) return rawDesc;
    return null;
  }
}

/// Character Background origin definition.
@immutable
class Background extends DomainEntity {
  @override
  final EntityId id;
  @override
  final String name;
  final String? abilityScoreSummary;
  final String? originFeat;
  final List<String> skillProficiencies;
  final List<String> toolProficiencies;
  final List<String> languages;
  final String descriptionMarkdown;
  /// Declarative mechanic grants emitted by this background (e.g., fixed skill proficiencies).
  final List<FeatureGrant> grants;
  @override
  final Map<String, dynamic> customProperties;

  const Background({
    required this.id,
    required this.name,
    this.abilityScoreSummary,
    this.originFeat,
    this.skillProficiencies = const [],
    this.toolProficiencies = const [],
    this.languages = const [],
    required this.descriptionMarkdown,
    this.grants = const [],
    this.customProperties = const {},
  });

  @override
  EntityType get entityType => EntityType.background;

  @override
  Map<String, dynamic> toMap() => {
        'id': id.toMap(),
        'name': name,
        'abilityScoreSummary': abilityScoreSummary,
        'originFeat': originFeat,
        'skillProficiencies': skillProficiencies,
        'toolProficiencies': toolProficiencies,
        'languages': languages,
        'descriptionMarkdown': descriptionMarkdown,
        'grants': grants.map((g) => g.toMap()).toList(),
        'customProperties': customProperties,
      };

  factory Background.fromMap(Map<String, dynamic> map) {
    return Background(
      id: EntityId.fromMap(Map<String, dynamic>.from(map['id'] as Map? ?? {})),
      name: map['name']?.toString() ?? '',
      abilityScoreSummary: map['abilityScoreSummary']?.toString(),
      originFeat: map['originFeat']?.toString(),
      skillProficiencies: (map['skillProficiencies'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
      toolProficiencies: (map['toolProficiencies'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
      languages: (map['languages'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
      descriptionMarkdown: map['descriptionMarkdown']?.toString() ?? '',
      grants: (map['grants'] as List? ?? [])
          .whereType<Map>()
          .map((g) => FeatureGrant.fromMap(Map<String, dynamic>.from(g)))
          .toList(),
      customProperties:
          Map<String, dynamic>.from(map['customProperties'] as Map? ?? {}),
    );
  }

  Background copyWith({
    EntityId? id,
    String? name,
    String? abilityScoreSummary,
    String? originFeat,
    List<String>? skillProficiencies,
    List<String>? toolProficiencies,
    List<String>? languages,
    String? descriptionMarkdown,
    List<FeatureGrant>? grants,
    Map<String, dynamic>? customProperties,
  }) {
    return Background(
      id: id ?? this.id,
      name: name ?? this.name,
      abilityScoreSummary: abilityScoreSummary ?? this.abilityScoreSummary,
      originFeat: originFeat ?? this.originFeat,
      skillProficiencies: skillProficiencies ?? this.skillProficiencies,
      toolProficiencies: toolProficiencies ?? this.toolProficiencies,
      languages: languages ?? this.languages,
      descriptionMarkdown: descriptionMarkdown ?? this.descriptionMarkdown,
      grants: grants ?? this.grants,
      customProperties: customProperties ?? this.customProperties,
    );
  }

  /// Returns a markdown description tailored for the specified ruleset.
  /// Under 2014 rules, 2024 mechanics like Origin Feats and Background Ability
  /// Score increases are omitted by stripping their lines.
  String getDescriptionForRuleset(RulesetVersion ruleset) {
    if (ruleset == RulesetVersion.v2014) {
      final lines = descriptionMarkdown.split('\n');
      final filtered = lines.where((line) {
        final trimmed = line.trim();
        if (trimmed.startsWith('**Origin Feat:**') ||
            trimmed.startsWith('Origin Feat:') ||
            trimmed.startsWith('**Ability Scores:**') ||
            trimmed.startsWith('Ability Scores:')) {
          return false;
        }
        return true;
      }).toList();
      return filtered.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
    }
    return descriptionMarkdown;
  }
}

/// Generic homebrew compendium entry (tables, variant rules, conditions, hazards, boons, etc.).
@immutable
class HomebrewCompendiumEntry extends DomainEntity {
  @override
  final EntityId id;
  @override
  final String name;
  final String category; // e.g. "Table", "Rule", "Optional Feature", "Condition", "Hazard", "Reward"
  final String descriptionMarkdown;
  @override
  final Map<String, dynamic> customProperties;

  const HomebrewCompendiumEntry({
    required this.id,
    required this.name,
    required this.category,
    required this.descriptionMarkdown,
    this.customProperties = const {},
  });

  @override
  EntityType get entityType => EntityType.custom;

  @override
  Map<String, dynamic> toMap() => {
        'id': id.toMap(),
        'name': name,
        'category': category,
        'descriptionMarkdown': descriptionMarkdown,
        'customProperties': customProperties,
      };

  factory HomebrewCompendiumEntry.fromMap(Map<String, dynamic> map) {
    return HomebrewCompendiumEntry(
      id: EntityId.fromMap(Map<String, dynamic>.from(map['id'] as Map? ?? {})),
      name: map['name']?.toString() ?? '',
      category: map['category']?.toString() ?? 'General',
      descriptionMarkdown: map['descriptionMarkdown']?.toString() ?? '',
      customProperties:
          Map<String, dynamic>.from(map['customProperties'] as Map? ?? {}),
    );
  }

  HomebrewCompendiumEntry copyWith({
    EntityId? id,
    String? name,
    String? category,
    String? descriptionMarkdown,
    Map<String, dynamic>? customProperties,
  }) {
    return HomebrewCompendiumEntry(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      descriptionMarkdown: descriptionMarkdown ?? this.descriptionMarkdown,
      customProperties: customProperties ?? this.customProperties,
    );
  }
}
