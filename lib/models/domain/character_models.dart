import 'package:flutter/foundation.dart';
import 'core_types.dart';
import 'entity_reference.dart';
import 'spell_monster_equipment.dart';
import '../party/party_purse.dart';
import '../dm_screen_data.dart' show DmRulesEdition;
import '../../services/rules/dnd_5e_rules_engine.dart';

/// 5e Core Ability Score Keys
enum AbilityType {
  strength,
  dexterity,
  constitution,
  intelligence,
  wisdom,
  charisma;

  String get shortName => switch (this) {
        AbilityType.strength => 'STR',
        AbilityType.dexterity => 'DEX',
        AbilityType.constitution => 'CON',
        AbilityType.intelligence => 'INT',
        AbilityType.wisdom => 'WIS',
        AbilityType.charisma => 'CHA',
      };

  /// Safely resolves a loose or unstructured string into a canonical [AbilityType].
  static AbilityType fromLooseString(
    String? key, [
    AbilityType fallback = AbilityType.strength,
  ]) {
    if (key == null) return fallback;
    final clean = key.trim().toLowerCase();
    return switch (clean) {
      'str' || 'strength' => AbilityType.strength,
      'dex' || 'dexterity' => AbilityType.dexterity,
      'con' || 'constitution' => AbilityType.constitution,
      'int' || 'intelligence' => AbilityType.intelligence,
      'wis' || 'wisdom' => AbilityType.wisdom,
      'cha' || 'charisma' => AbilityType.charisma,
      _ => AbilityType.values.firstWhere(
          (a) => a.name.toLowerCase() == clean,
          orElse: () => fallback,
        ),
    };
  }
}

/// Immutable collection of the 6 core 5e Ability Scores
@immutable
class AbilityScores {
  final int strength;
  final int dexterity;
  final int constitution;
  final int intelligence;
  final int wisdom;
  final int charisma;

  const AbilityScores({
    this.strength = 10,
    this.dexterity = 10,
    this.constitution = 10,
    this.intelligence = 10,
    this.wisdom = 10,
    this.charisma = 10,
  });

  const AbilityScores.standardArray()
      : strength = 15,
        dexterity = 14,
        constitution = 13,
        intelligence = 12,
        wisdom = 10,
        charisma = 8;

  int getScore(AbilityType ability) => switch (ability) {
        AbilityType.strength => strength,
        AbilityType.dexterity => dexterity,
        AbilityType.constitution => constitution,
        AbilityType.intelligence => intelligence,
        AbilityType.wisdom => wisdom,
        AbilityType.charisma => charisma,
      };

  int getModifier(AbilityType ability) => getScore(ability).dndModifier;

  AbilityScores withBonus(AbilityScores bonus) {
    return AbilityScores(
      strength: strength + bonus.strength,
      dexterity: dexterity + bonus.dexterity,
      constitution: constitution + bonus.constitution,
      intelligence: intelligence + bonus.intelligence,
      wisdom: wisdom + bonus.wisdom,
      charisma: charisma + bonus.charisma,
    );
  }

  AbilityScores copyWith({
    int? strength,
    int? dexterity,
    int? constitution,
    int? intelligence,
    int? wisdom,
    int? charisma,
  }) {
    return AbilityScores(
      strength: strength ?? this.strength,
      dexterity: dexterity ?? this.dexterity,
      constitution: constitution ?? this.constitution,
      intelligence: intelligence ?? this.intelligence,
      wisdom: wisdom ?? this.wisdom,
      charisma: charisma ?? this.charisma,
    );
  }

  Map<String, int> toMap() => {
        'strength': strength,
        'dexterity': dexterity,
        'constitution': constitution,
        'intelligence': intelligence,
        'wisdom': wisdom,
        'charisma': charisma,
      };

  factory AbilityScores.fromMap(Map<String, dynamic> map) {
    return AbilityScores(
      strength: (map['strength'] as num?)?.toInt() ?? 10,
      dexterity: (map['dexterity'] as num?)?.toInt() ?? 10,
      constitution: (map['constitution'] as num?)?.toInt() ?? 10,
      intelligence: (map['intelligence'] as num?)?.toInt() ?? 10,
      wisdom: (map['wisdom'] as num?)?.toInt() ?? 10,
      charisma: (map['charisma'] as num?)?.toInt() ?? 10,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AbilityScores &&
          runtimeType == other.runtimeType &&
          strength == other.strength &&
          dexterity == other.dexterity &&
          constitution == other.constitution &&
          intelligence == other.intelligence &&
          wisdom == other.wisdom &&
          charisma == other.charisma;

  @override
  int get hashCode =>
      strength.hashCode ^
      dexterity.hashCode ^
      constitution.hashCode ^
      intelligence.hashCode ^
      wisdom.hashCode ^
      charisma.hashCode;
}

/// Standard 5e Skills
enum SkillType {
  acrobatics,
  animalHandling,
  arcana,
  athletics,
  deception,
  history,
  insight,
  intimidation,
  investigation,
  medicine,
  nature,
  perception,
  performance,
  persuasion,
  religion,
  sleightOfHand,
  stealth,
  survival;

  AbilityType get defaultAbility => switch (this) {
        SkillType.athletics => AbilityType.strength,
        SkillType.acrobatics ||
        SkillType.sleightOfHand ||
        SkillType.stealth => AbilityType.dexterity,
        SkillType.arcana ||
        SkillType.history ||
        SkillType.investigation ||
        SkillType.nature ||
        SkillType.religion => AbilityType.intelligence,
        SkillType.animalHandling ||
        SkillType.insight ||
        SkillType.medicine ||
        SkillType.perception ||
        SkillType.survival => AbilityType.wisdom,
        SkillType.deception ||
        SkillType.intimidation ||
        SkillType.performance ||
        SkillType.persuasion => AbilityType.charisma,
      };

  String get displayName => switch (this) {
        SkillType.acrobatics => 'Acrobatics',
        SkillType.animalHandling => 'Animal Handling',
        SkillType.arcana => 'Arcana',
        SkillType.athletics => 'Athletics',
        SkillType.deception => 'Deception',
        SkillType.history => 'History',
        SkillType.insight => 'Insight',
        SkillType.intimidation => 'Intimidation',
        SkillType.investigation => 'Investigation',
        SkillType.medicine => 'Medicine',
        SkillType.nature => 'Nature',
        SkillType.perception => 'Perception',
        SkillType.performance => 'Performance',
        SkillType.persuasion => 'Persuasion',
        SkillType.religion => 'Religion',
        SkillType.sleightOfHand => 'Sleight of Hand',
        SkillType.stealth => 'Stealth',
        SkillType.survival => 'Survival',
      };
}

/// Skill Proficiency Levels
enum SkillProficiencyLevel {
  none(0.0),
  jackOfAllTrades(0.5),
  proficient(1.0),
  expertise(2.0);

  final double multiplier;
  const SkillProficiencyLevel(this.multiplier);
}

/// Equipment and Wearable Slots
enum EquipmentSlot {
  head,
  cloak,
  armor,
  shield,
  mainHand,
  offHand,
  twoHand,
  ring1,
  ring2,
  boots,
  wondrous;

  String get displayName => switch (this) {
        EquipmentSlot.head => 'Head',
        EquipmentSlot.cloak => 'Cloak',
        EquipmentSlot.armor => 'Armor',
        EquipmentSlot.shield => 'Shield',
        EquipmentSlot.mainHand => 'Main Hand',
        EquipmentSlot.offHand => 'Off Hand',
        EquipmentSlot.twoHand => 'Two-Handed',
        EquipmentSlot.ring1 => 'Ring 1',
        EquipmentSlot.ring2 => 'Ring 2',
        EquipmentSlot.boots => 'Boots',
        EquipmentSlot.wondrous => 'Wondrous',
      };
}

/// Individual item instance in a character or container inventory
@immutable
class InventoryItemInstance {
  final String instanceId;
  final EntityReference<EquipmentItem> itemRef;
  final int quantity;
  final bool isEquipped;
  final EquipmentSlot? equippedSlot;
  final bool isAttuned;
  final bool requiresAttunement;
  final String? customName;
  final String? notes;
  final Map<String, dynamic> customProperties;

  const InventoryItemInstance({
    required this.instanceId,
    required this.itemRef,
    this.quantity = 1,
    this.isEquipped = false,
    this.equippedSlot,
    this.isAttuned = false,
    this.requiresAttunement = false,
    this.customName,
    this.notes,
    this.customProperties = const {},
  });

  String get displayName => customName ?? itemRef.displayName;

  InventoryItemInstance copyWith({
    String? instanceId,
    EntityReference<EquipmentItem>? itemRef,
    int? quantity,
    bool? isEquipped,
    EquipmentSlot? equippedSlot,
    bool? isAttuned,
    bool? requiresAttunement,
    String? customName,
    String? notes,
    Map<String, dynamic>? customProperties,
  }) {
    return InventoryItemInstance(
      instanceId: instanceId ?? this.instanceId,
      itemRef: itemRef ?? this.itemRef,
      quantity: quantity ?? this.quantity,
      isEquipped: isEquipped ?? this.isEquipped,
      equippedSlot: isEquipped == false ? null : (equippedSlot ?? this.equippedSlot),
      isAttuned: isAttuned ?? this.isAttuned,
      requiresAttunement: requiresAttunement ?? this.requiresAttunement,
      customName: customName ?? this.customName,
      notes: notes ?? this.notes,
      customProperties: customProperties ?? this.customProperties,
    );
  }

  Map<String, dynamic> toMap() => {
        'instanceId': instanceId,
        'itemRef': itemRef.toMap(),
        'quantity': quantity,
        'isEquipped': isEquipped,
        'equippedSlot': equippedSlot?.name,
        'isAttuned': isAttuned,
        'requiresAttunement': requiresAttunement,
        'customName': customName,
        'notes': notes,
        'customProperties': customProperties,
      };

  factory InventoryItemInstance.fromMap(Map<String, dynamic> map) {
    EquipmentSlot? slot;
    if (map['equippedSlot'] != null) {
      final sStr = map['equippedSlot'].toString();
      slot = EquipmentSlot.values.firstWhere(
        (s) => s.name == sStr,
        orElse: () => EquipmentSlot.wondrous,
      );
    }

    return InventoryItemInstance(
      instanceId: map['instanceId']?.toString() ?? '',
      itemRef: EntityReference<EquipmentItem>.fromMap(
          Map<String, dynamic>.from(map['itemRef'] as Map? ?? {})),
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      isEquipped: map['isEquipped'] == true,
      equippedSlot: slot,
      isAttuned: map['isAttuned'] == true,
      requiresAttunement: map['requiresAttunement'] == true,
      customName: map['customName']?.toString(),
      notes: map['notes']?.toString(),
      customProperties:
          Map<String, dynamic>.from(map['customProperties'] as Map? ?? {}),
    );
  }
}

/// Single class progression slice (supporting single class or multiclassing)
@immutable
class ClassLevelProgression {
  final EntityReference<DomainEntity> classRef;
  final EntityReference<DomainEntity>? subclassRef;
  final int level;
  final String hitDie; // e.g. "d8", "d10", "d12", "d6"
  final List<int> hitPointsRolled; // HP gained per level above 1st
  final bool isStartingClass;
  final Map<String, List<String>> selectedFeatureOptions; // decisionId -> [selectedOptionIds]

  const ClassLevelProgression({
    required this.classRef,
    this.subclassRef,
    this.level = 1,
    required this.hitDie,
    this.hitPointsRolled = const [],
    this.isStartingClass = false,
    this.selectedFeatureOptions = const {},
  });

  int get hitDieSides {
    final clean = hitDie.replaceAll('d', '').trim();
    return int.tryParse(clean) ?? 8;
  }

  int get averageHpPerLevel => (hitDieSides / 2).floor() + 1;

  ClassLevelProgression copyWith({
    EntityReference<DomainEntity>? classRef,
    EntityReference<DomainEntity>? subclassRef,
    int? level,
    String? hitDie,
    List<int>? hitPointsRolled,
    bool? isStartingClass,
    Map<String, List<String>>? selectedFeatureOptions,
  }) {
    return ClassLevelProgression(
      classRef: classRef ?? this.classRef,
      subclassRef: subclassRef ?? this.subclassRef,
      level: level ?? this.level,
      hitDie: hitDie ?? this.hitDie,
      hitPointsRolled: hitPointsRolled ?? this.hitPointsRolled,
      isStartingClass: isStartingClass ?? this.isStartingClass,
      selectedFeatureOptions: selectedFeatureOptions ?? this.selectedFeatureOptions,
    );
  }

  Map<String, dynamic> toMap() => {
        'classRef': classRef.toMap(),
        'subclassRef': subclassRef?.toMap(),
        'level': level,
        'hitDie': hitDie,
        'hitPointsRolled': hitPointsRolled,
        'isStartingClass': isStartingClass,
        'selectedFeatureOptions': selectedFeatureOptions,
      };

  factory ClassLevelProgression.fromMap(Map<String, dynamic> map) {
    final rawOptions = map['selectedFeatureOptions'];
    final parsedOptions = <String, List<String>>{};
    if (rawOptions is Map) {
      rawOptions.forEach((key, val) {
        if (val is List) {
          parsedOptions[key.toString()] = val.map((e) => e.toString()).toList();
        } else if (val != null) {
          parsedOptions[key.toString()] = [val.toString()];
        }
      });
    }

    return ClassLevelProgression(
      classRef: EntityReference<DomainEntity>.fromMap(
          Map<String, dynamic>.from(map['classRef'] as Map? ?? {})),
      subclassRef: map['subclassRef'] != null
          ? EntityReference<DomainEntity>.fromMap(
              Map<String, dynamic>.from(map['subclassRef'] as Map? ?? {}))
          : null,
      level: (map['level'] as num?)?.toInt() ?? 1,
      hitDie: map['hitDie']?.toString() ?? 'd8',
      hitPointsRolled: (map['hitPointsRolled'] as List? ?? [])
          .whereType<num>()
          .map((n) => n.toInt())
          .toList(),
      isStartingClass: map['isStartingClass'] == true,
      selectedFeatureOptions: parsedOptions,
    );
  }
}

/// Overall Character Progression aggregating all class levels
@immutable
class CharacterProgression {
  final List<ClassLevelProgression> classes;
  final int experiencePoints;

  const CharacterProgression({
    required this.classes,
    this.experiencePoints = 0,
  });

  int get totalLevel => classes.fold(0, (sum, c) => sum + c.level);

  ClassLevelProgression? get startingClass =>
      classes.where((c) => c.isStartingClass).firstOrNull ?? classes.firstOrNull;

  ClassLevelProgression? getClass(String classSlug) =>
      classes.where((c) => c.classRef.slug == classSlug).firstOrNull;

  /// Retrieves all selected option IDs for a specific decision across all classes.
  List<String> getSelectedOptionsForDecision(String decisionId) {
    final results = <String>[];
    for (final c in classes) {
      final opts = c.selectedFeatureOptions[decisionId];
      if (opts != null) results.addAll(opts);
    }
    return results;
  }

  /// Aggregates all selected feature option IDs across all classes.
  Map<String, List<String>> getAllSelectedFeatureOptions() {
    final merged = <String, List<String>>{};
    for (final c in classes) {
      c.selectedFeatureOptions.forEach((k, v) {
        merged.putIfAbsent(k, () => []).addAll(v);
      });
    }
    return merged;
  }

  CharacterProgression copyWith({
    List<ClassLevelProgression>? classes,
    int? experiencePoints,
  }) {
    return CharacterProgression(
      classes: classes ?? this.classes,
      experiencePoints: experiencePoints ?? this.experiencePoints,
    );
  }

  Map<String, dynamic> toMap() => {
        'classes': classes.map((c) => c.toMap()).toList(),
        'experiencePoints': experiencePoints,
      };

  factory CharacterProgression.fromMap(Map<String, dynamic> map) {
    return CharacterProgression(
      classes: (map['classes'] as List? ?? [])
          .whereType<Map>()
          .map((c) => ClassLevelProgression.fromMap(Map<String, dynamic>.from(c)))
          .toList(),
      experiencePoints: (map['experiencePoints'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Standard 5e Spell Slots Pool
@immutable
class SpellSlotPool {
  final Map<int, int> currentSlots; // Level 1-9 available slots
  final Map<int, int> maxSlots; // Level 1-9 max slots
  final int pactMagicSlotLevel; // 1-5
  final int pactMagicMax;
  final int pactMagicCurrent;

  const SpellSlotPool({
    this.currentSlots = const {},
    this.maxSlots = const {},
    this.pactMagicSlotLevel = 0,
    this.pactMagicMax = 0,
    this.pactMagicCurrent = 0,
  });

  SpellSlotPool copyWith({
    Map<int, int>? currentSlots,
    Map<int, int>? maxSlots,
    int? pactMagicSlotLevel,
    int? pactMagicMax,
    int? pactMagicCurrent,
  }) {
    return SpellSlotPool(
      currentSlots: currentSlots ?? this.currentSlots,
      maxSlots: maxSlots ?? this.maxSlots,
      pactMagicSlotLevel: pactMagicSlotLevel ?? this.pactMagicSlotLevel,
      pactMagicMax: pactMagicMax ?? this.pactMagicMax,
      pactMagicCurrent: pactMagicCurrent ?? this.pactMagicCurrent,
    );
  }

  Map<String, dynamic> toMap() => {
        'currentSlots': currentSlots.map((k, v) => MapEntry(k.toString(), v)),
        'maxSlots': maxSlots.map((k, v) => MapEntry(k.toString(), v)),
        'pactMagicSlotLevel': pactMagicSlotLevel,
        'pactMagicMax': pactMagicMax,
        'pactMagicCurrent': pactMagicCurrent,
      };

  factory SpellSlotPool.fromMap(Map<String, dynamic> map) {
    final cur = <int, int>{};
    if (map['currentSlots'] is Map) {
      (map['currentSlots'] as Map).forEach((k, v) {
        final key = int.tryParse(k.toString());
        if (key != null && v is num) cur[key] = v.toInt();
      });
    }

    final max = <int, int>{};
    if (map['maxSlots'] is Map) {
      (map['maxSlots'] as Map).forEach((k, v) {
        final key = int.tryParse(k.toString());
        if (key != null && v is num) max[key] = v.toInt();
      });
    }

    return SpellSlotPool(
      currentSlots: cur,
      maxSlots: max,
      pactMagicSlotLevel: (map['pactMagicSlotLevel'] as num?)?.toInt() ?? 0,
      pactMagicMax: (map['pactMagicMax'] as num?)?.toInt() ?? 0,
      pactMagicCurrent: (map['pactMagicCurrent'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Character resource pools (HP, Hit Dice, Spell Slots, Class charges)
@immutable
class CharacterResourcePool {
  final int currentHp;
  final int tempHp;
  final Map<String, int> currentHitDice; // e.g. {"d8": 3, "d10": 1}
  final SpellSlotPool spellSlots;
  final Map<String, int> customResourcesCurrent; // e.g. {"ki": 4, "rage": 2}
  final Map<String, int> customResourcesMax;

  const CharacterResourcePool({
    required this.currentHp,
    this.tempHp = 0,
    this.currentHitDice = const {},
    this.spellSlots = const SpellSlotPool(),
    this.customResourcesCurrent = const {},
    this.customResourcesMax = const {},
  });

  CharacterResourcePool copyWith({
    int? currentHp,
    int? tempHp,
    Map<String, int>? currentHitDice,
    SpellSlotPool? spellSlots,
    Map<String, int>? customResourcesCurrent,
    Map<String, int>? customResourcesMax,
  }) {
    return CharacterResourcePool(
      currentHp: currentHp ?? this.currentHp,
      tempHp: tempHp ?? this.tempHp,
      currentHitDice: currentHitDice ?? this.currentHitDice,
      spellSlots: spellSlots ?? this.spellSlots,
      customResourcesCurrent:
          customResourcesCurrent ?? this.customResourcesCurrent,
      customResourcesMax: customResourcesMax ?? this.customResourcesMax,
    );
  }

  Map<String, dynamic> toMap() => {
        'currentHp': currentHp,
        'tempHp': tempHp,
        'currentHitDice': currentHitDice,
        'spellSlots': spellSlots.toMap(),
        'customResourcesCurrent': customResourcesCurrent,
        'customResourcesMax': customResourcesMax,
      };

  factory CharacterResourcePool.fromMap(Map<String, dynamic> map) {
    return CharacterResourcePool(
      currentHp: (map['currentHp'] as num?)?.toInt() ?? 10,
      tempHp: (map['tempHp'] as num?)?.toInt() ?? 0,
      currentHitDice: Map<String, int>.from(map['currentHitDice'] as Map? ?? {}),
      spellSlots: SpellSlotPool.fromMap(
          Map<String, dynamic>.from(map['spellSlots'] as Map? ?? {})),
      customResourcesCurrent:
          Map<String, int>.from(map['customResourcesCurrent'] as Map? ?? {}),
      customResourcesMax:
          Map<String, int>.from(map['customResourcesMax'] as Map? ?? {}),
    );
  }
}

/// Active Condition and Temporary Status Effect
@immutable
class CharacterCondition {
  final String conditionName; // e.g. "blinded", "poisoned", "haste"
  final int durationSeconds; // 0 = indefinite
  final String? source; // spell or effect name
  final Map<String, dynamic> parameters;

  const CharacterCondition({
    required this.conditionName,
    this.durationSeconds = 0,
    this.source,
    this.parameters = const {},
  });

  Map<String, dynamic> toMap() => {
        'conditionName': conditionName,
        'durationSeconds': durationSeconds,
        'source': source,
        'parameters': parameters,
      };

  factory CharacterCondition.fromMap(Map<String, dynamic> map) {
    return CharacterCondition(
      conditionName: map['conditionName']?.toString() ?? '',
      durationSeconds: (map['durationSeconds'] as num?)?.toInt() ?? 0,
      source: map['source']?.toString(),
      parameters: Map<String, dynamic>.from(map['parameters'] as Map? ?? {}),
    );
  }
}

/// Root Character Domain Entity adhering to DomainEntity interface
@immutable
class Character extends DomainEntity {
  @override
  final EntityId id;
  @override
  final String name;
  final EntityReference<DomainEntity> speciesRef;
  final EntityReference<DomainEntity>? backgroundRef;
  final CharacterProgression progression;
  final AbilityScores baseScores;
  final AbilityScores bonusScores; // Permanent bonuses from species/background/feats
  final Map<SkillType, SkillProficiencyLevel> skillProficiencies;
  final Set<AbilityType> savingThrowProficiencies;
  final List<String> toolProficiencies;
  final List<String> languages;
  final List<InventoryItemInstance> inventory;
  final PartyPurse purse;
  final List<EntityReference<Spell>> cantrips;
  final List<EntityReference<Spell>> spellsKnown;
  final List<EntityReference<Spell>> spellsPrepared;
  final List<EntityReference<DomainEntity>> feats;
  final CharacterResourcePool resources;
  final List<CharacterCondition> conditions;
  final int maxAttunementSlots;
  final int baseSpeedFeet;
  final DmRulesEdition rulesEdition;
  @override
  final Map<String, dynamic> customProperties;

  Character({
    required this.id,
    required this.name,
    required this.speciesRef,
    this.backgroundRef,
    required this.progression,
    required this.baseScores,
    this.bonusScores = const AbilityScores(
      strength: 0,
      dexterity: 0,
      constitution: 0,
      intelligence: 0,
      wisdom: 0,
      charisma: 0,
    ),
    this.skillProficiencies = const {},
    this.savingThrowProficiencies = const {},
    this.toolProficiencies = const [],
    this.languages = const ['Common'],
    this.inventory = const [],
    this.purse = const PartyPurse(),
    this.cantrips = const [],
    this.spellsKnown = const [],
    this.spellsPrepared = const [],
    this.feats = const [],
    required this.resources,
    this.conditions = const [],
    this.maxAttunementSlots = 3,
    this.baseSpeedFeet = 30,
    this.rulesEdition = DmRulesEdition.v2014,
    this.customProperties = const {},
  });

  @override
  EntityType get entityType => EntityType.character;

  int get totalLevel => progression.totalLevel;
  int get proficiencyBonus => totalLevel.dndProficiencyBonus;

  int get attunedItemCount =>
      inventory.where((item) => item.isAttuned).length;

  List<InventoryItemInstance> get equippedItems =>
      inventory.where((item) => item.isEquipped).toList();

  @override
  Map<String, dynamic> toMap() => {
        'id': id.toMap(),
        'name': name,
        'speciesRef': speciesRef.toMap(),
        'backgroundRef': backgroundRef?.toMap(),
        'progression': progression.toMap(),
        'baseScores': baseScores.toMap(),
        'bonusScores': bonusScores.toMap(),
        'skillProficiencies': skillProficiencies
            .map((k, v) => MapEntry(k.name, v.name)),
        'savingThrowProficiencies':
            savingThrowProficiencies.map((a) => a.name).toList(),
        'toolProficiencies': toolProficiencies,
        'languages': languages,
        'inventory': inventory.map((i) => i.toMap()).toList(),
        'purse': purse.toMap(),
        'cantrips': cantrips.map((c) => c.toMap()).toList(),
        'spellsKnown': spellsKnown.map((s) => s.toMap()).toList(),
        'spellsPrepared': spellsPrepared.map((s) => s.toMap()).toList(),
        'feats': feats.map((f) => f.toMap()).toList(),
        'resources': resources.toMap(),
        'conditions': conditions.map((c) => c.toMap()).toList(),
        'maxAttunementSlots': maxAttunementSlots,
        'baseSpeedFeet': baseSpeedFeet,
        'rulesEdition': rulesEdition.name,
        'customProperties': customProperties,
      };

  factory Character.fromMap(Map<String, dynamic> map) {
    final skills = <SkillType, SkillProficiencyLevel>{};
    if (map['skillProficiencies'] is Map) {
      (map['skillProficiencies'] as Map).forEach((k, v) {
        final skill = SkillType.values.firstWhere(
          (s) => s.name == k.toString(),
          orElse: () => SkillType.perception,
        );
        final level = SkillProficiencyLevel.values.firstWhere(
          (l) => l.name == v.toString(),
          orElse: () => SkillProficiencyLevel.proficient,
        );
        skills[skill] = level;
      });
    }

    final saves = <AbilityType>{};
    if (map['savingThrowProficiencies'] is List) {
      for (final s in (map['savingThrowProficiencies'] as List)) {
        final ab = AbilityType.values.firstWhere(
          (a) => a.name == s.toString(),
          orElse: () => AbilityType.strength,
        );
        saves.add(ab);
      }
    }

    final edition = map['rulesEdition'] != null
        ? DmRulesEdition.values.firstWhere(
            (e) => e.name == map['rulesEdition'].toString(),
            orElse: () => DmRulesEdition.v2014,
          )
        : DmRulesEdition.v2014;

    return Character(
      id: EntityId.fromMap(Map<String, dynamic>.from(map['id'] as Map? ?? {})),
      name: map['name']?.toString() ?? '',
      speciesRef: EntityReference<DomainEntity>.fromMap(
          Map<String, dynamic>.from(map['speciesRef'] as Map? ?? {})),
      backgroundRef: map['backgroundRef'] != null
          ? EntityReference<DomainEntity>.fromMap(
              Map<String, dynamic>.from(map['backgroundRef'] as Map? ?? {}))
          : null,
      progression: CharacterProgression.fromMap(
          Map<String, dynamic>.from(map['progression'] as Map? ?? {})),
      baseScores: AbilityScores.fromMap(
          Map<String, dynamic>.from(map['baseScores'] as Map? ?? {})),
      bonusScores: AbilityScores.fromMap(
          Map<String, dynamic>.from(map['bonusScores'] as Map? ?? {})),
      skillProficiencies: skills,
      savingThrowProficiencies: saves,
      toolProficiencies: (map['toolProficiencies'] as List? ?? [])
          .whereType<String>()
          .toList(),
      languages:
          (map['languages'] as List? ?? ['Common']).whereType<String>().toList(),
      inventory: (map['inventory'] as List? ?? [])
          .whereType<Map>()
          .map((i) =>
              InventoryItemInstance.fromMap(Map<String, dynamic>.from(i)))
          .toList(),
      purse: map['purse'] != null
          ? PartyPurse.fromMap(
              Map<String, dynamic>.from(map['purse'] as Map? ?? {}))
          : const PartyPurse(),
      cantrips: (map['cantrips'] as List? ?? [])
          .whereType<Map>()
          .map((c) => EntityReference<Spell>.fromMap(Map<String, dynamic>.from(c)))
          .toList(),
      spellsKnown: (map['spellsKnown'] as List? ?? [])
          .whereType<Map>()
          .map((s) => EntityReference<Spell>.fromMap(Map<String, dynamic>.from(s)))
          .toList(),
      spellsPrepared: (map['spellsPrepared'] as List? ?? [])
          .whereType<Map>()
          .map((s) => EntityReference<Spell>.fromMap(Map<String, dynamic>.from(s)))
          .toList(),
      feats: (map['feats'] as List? ?? [])
          .whereType<Map>()
          .map((f) =>
              EntityReference<DomainEntity>.fromMap(Map<String, dynamic>.from(f)))
          .toList(),
      resources: CharacterResourcePool.fromMap(
          Map<String, dynamic>.from(map['resources'] as Map? ?? {})),
      conditions: (map['conditions'] as List? ?? [])
          .whereType<Map>()
          .map((c) =>
              CharacterCondition.fromMap(Map<String, dynamic>.from(c)))
          .toList(),
      maxAttunementSlots:
          (map['maxAttunementSlots'] as num?)?.toInt() ?? 3,
      baseSpeedFeet: (map['baseSpeedFeet'] as num?)?.toInt() ?? 30,
      rulesEdition: edition,
      customProperties:
          Map<String, dynamic>.from(map['customProperties'] as Map? ?? {}),
    );
  }

  Character copyWith({
    EntityId? id,
    String? name,
    EntityReference<DomainEntity>? speciesRef,
    EntityReference<DomainEntity>? backgroundRef,
    CharacterProgression? progression,
    AbilityScores? baseScores,
    AbilityScores? bonusScores,
    Map<SkillType, SkillProficiencyLevel>? skillProficiencies,
    Set<AbilityType>? savingThrowProficiencies,
    List<String>? toolProficiencies,
    List<String>? languages,
    List<InventoryItemInstance>? inventory,
    PartyPurse? purse,
    List<EntityReference<Spell>>? cantrips,
    List<EntityReference<Spell>>? spellsKnown,
    List<EntityReference<Spell>>? spellsPrepared,
    List<EntityReference<DomainEntity>>? feats,
    CharacterResourcePool? resources,
    List<CharacterCondition>? conditions,
    int? maxAttunementSlots,
    int? baseSpeedFeet,
    DmRulesEdition? rulesEdition,
    Map<String, dynamic>? customProperties,
  }) {
    return Character(
      id: id ?? this.id,
      name: name ?? this.name,
      speciesRef: speciesRef ?? this.speciesRef,
      backgroundRef: backgroundRef ?? this.backgroundRef,
      progression: progression ?? this.progression,
      baseScores: baseScores ?? this.baseScores,
      bonusScores: bonusScores ?? this.bonusScores,
      skillProficiencies: skillProficiencies ?? this.skillProficiencies,
      savingThrowProficiencies:
          savingThrowProficiencies ?? this.savingThrowProficiencies,
      toolProficiencies: toolProficiencies ?? this.toolProficiencies,
      languages: languages ?? this.languages,
      inventory: inventory ?? this.inventory,
      purse: purse ?? this.purse,
      cantrips: cantrips ?? this.cantrips,
      spellsKnown: spellsKnown ?? this.spellsKnown,
      spellsPrepared: spellsPrepared ?? this.spellsPrepared,
      feats: feats ?? this.feats,
      resources: resources ?? this.resources,
      conditions: conditions ?? this.conditions,
      maxAttunementSlots: maxAttunementSlots ?? this.maxAttunementSlots,
      baseSpeedFeet: baseSpeedFeet ?? this.baseSpeedFeet,
      rulesEdition: rulesEdition ?? this.rulesEdition,
      customProperties: customProperties ?? this.customProperties,
    );
  }
}
