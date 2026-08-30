import 'package:flutter/foundation.dart';
import '../dm_screen_data.dart';
import 'core_types.dart';
import 'entity_reference.dart';

/// Types of class decision points encountered during character creation and progression.
enum FeatureChoiceType {
  subclassSelection,
  fightingStyle,
  invocations,
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
  final RulesetVersion ruleset;
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
    this.ruleset = RulesetVersion.v2024,
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
        'ruleset': ruleset.name,
        'customProperties': customProperties,
      };

  factory ClassFeatureDecision.fromMap(Map<String, dynamic> map) {
    final typeName = map['type']?.toString();
    final type = FeatureChoiceType.values.firstWhere(
      (t) => t.name == typeName,
      orElse: () => FeatureChoiceType.customOption,
    );
    final rulesetName = map['ruleset']?.toString();
    final ruleset = RulesetVersion.values.firstWhere(
      (r) => r.name == rulesetName,
      orElse: () => RulesetVersion.v2024,
    );

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

/// Class definition representing a full 5e class progression, hit dice, proficiencies, and declarative feature decisions.
@immutable
class CharacterClass extends DomainEntity {
  @override
  final EntityId id;
  @override
  final String name;
  final String hitDie; // e.g. "d8", "d10", "d12"
  final String? primaryAbility;
  final List<String> savingThrows;
  final List<String> armorProficiencies;
  final List<String> weaponProficiencies;
  final String? spellcastingAbility;
  final String featuresMarkdown;
  final List<Subclass> subclasses;
  final int subclassSelectionLevel;
  final List<ClassFeatureDecision> featureDecisions;
  @override
  final Map<String, dynamic> customProperties;

  CharacterClass({
    required this.id,
    required this.name,
    required this.hitDie,
    this.primaryAbility,
    this.savingThrows = const [],
    this.armorProficiencies = const [],
    this.weaponProficiencies = const [],
    this.spellcastingAbility,
    required this.featuresMarkdown,
    this.subclasses = const [],
    this.subclassSelectionLevel = 3,
    this.featureDecisions = const [],
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
      if (ruleset != null && d.ruleset != ruleset && d.ruleset != RulesetVersion.homebrew) {
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
        'customProperties': customProperties,
      };

  factory CharacterClass.fromMap(Map<String, dynamic> map) {
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
      customProperties:
          Map<String, dynamic>.from(map['customProperties'] as Map? ?? {}),
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
  @override
  final Map<String, dynamic> customProperties;

  Subclass({
    required this.id,
    required this.name,
    required this.classSlug,
    String? shortName,
    required this.featuresMarkdown,
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
        'customProperties': customProperties,
      };

  factory Subclass.fromMap(Map<String, dynamic> map) {
    return Subclass(
      id: EntityId.fromMap(Map<String, dynamic>.from(map['id'] as Map? ?? {})),
      name: map['name']?.toString() ?? '',
      classSlug: map['classSlug']?.toString() ?? '',
      shortName: map['shortName']?.toString() ?? map['name']?.toString() ?? '',
      featuresMarkdown: map['featuresMarkdown']?.toString() ?? '',
      customProperties:
          Map<String, dynamic>.from(map['customProperties'] as Map? ?? {}),
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

  Subrace({
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
  @override
  final Map<String, dynamic> customProperties;

  Feat({
    required this.id,
    required this.name,
    this.prerequisite,
    this.category = 'General',
    required this.descriptionMarkdown,
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
        'customProperties': customProperties,
      };

  factory Feat.fromMap(Map<String, dynamic> map) {
    return Feat(
      id: EntityId.fromMap(Map<String, dynamic>.from(map['id'] as Map? ?? {})),
      name: map['name']?.toString() ?? '',
      prerequisite: map['prerequisite']?.toString(),
      category: map['category']?.toString() ?? 'General',
      descriptionMarkdown: map['descriptionMarkdown']?.toString() ?? '',
      customProperties:
          Map<String, dynamic>.from(map['customProperties'] as Map? ?? {}),
    );
  }

  Feat copyWith({
    EntityId? id,
    String? name,
    String? prerequisite,
    String? category,
    String? descriptionMarkdown,
    Map<String, dynamic>? customProperties,
  }) {
    return Feat(
      id: id ?? this.id,
      name: name ?? this.name,
      prerequisite: prerequisite ?? this.prerequisite,
      category: category ?? this.category,
      descriptionMarkdown: descriptionMarkdown ?? this.descriptionMarkdown,
      customProperties: customProperties ?? this.customProperties,
    );
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
  @override
  final Map<String, dynamic> customProperties;

  Background({
    required this.id,
    required this.name,
    this.abilityScoreSummary,
    this.originFeat,
    this.skillProficiencies = const [],
    this.toolProficiencies = const [],
    this.languages = const [],
    required this.descriptionMarkdown,
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
      customProperties: customProperties ?? this.customProperties,
    );
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

  HomebrewCompendiumEntry({
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
