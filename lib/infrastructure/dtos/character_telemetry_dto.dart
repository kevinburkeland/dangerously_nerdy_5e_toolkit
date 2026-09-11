import 'dart:convert';
import 'package:meta/meta.dart';

/// Lightweight pointer representing a single class progression level.
@immutable
class ClassLevelPointerDto {
  final String classSlug;
  final String? subclassSlug;
  final int level;

  const ClassLevelPointerDto({
    required this.classSlug,
    this.subclassSlug,
    required this.level,
  });

  factory ClassLevelPointerDto.fromMap(Map<String, dynamic> map) {
    final rawLevel = map['l'] ?? map['level'] ?? 1;
    final lvl = (rawLevel is num ? rawLevel.toInt() : 1).clamp(1, 20);

    return ClassLevelPointerDto(
      classSlug: (map['c'] ?? map['classSlug'] ?? '').toString().trim().toLowerCase(),
      subclassSlug: map['sc'] != null || map['subclassSlug'] != null
          ? (map['sc'] ?? map['subclassSlug']).toString().trim().toLowerCase()
          : null,
      level: lvl,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'c': classSlug,
      'l': level.clamp(1, 20),
    };
    if (subclassSlug != null && subclassSlug!.isNotEmpty) {
      map['sc'] = subclassSlug;
    }
    return map;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClassLevelPointerDto &&
          runtimeType == other.runtimeType &&
          classSlug == other.classSlug &&
          subclassSlug == other.subclassSlug &&
          level == other.level;

  @override
  int get hashCode => Object.hash(classSlug, subclassSlug, level);
}

/// Ephemeral combat telemetry and typed entity pointers (slugs) transmitted
/// across network rooms and party synchronization instead of full markdown sheets.
@immutable
class CharacterTelemetryDto {
  final String id;
  final String name;
  final String speciesSlug;
  final String? backgroundSlug;
  final List<ClassLevelPointerDto> classPointers;
  final int currentHp;
  final int maxHp;
  final int tempHp;
  final int armorClass;
  final int speed;
  final int level;
  final int passivePerception;
  final int exhaustionLevel;
  final int deathSaveSuccesses;
  final int deathSaveFailures;
  final List<String> conditions;
  final Map<String, int> spellSlots;
  final List<String> featSlugs;
  final List<String> equippedItemSlugs;
  final String rulesEdition;
  final int timestamp;
  final Map<String, dynamic> unparsedPayload;

  CharacterTelemetryDto({
    required this.id,
    required this.name,
    required this.speciesSlug,
    this.backgroundSlug,
    this.classPointers = const [],
    int currentHp = 10,
    int maxHp = 10,
    int tempHp = 0,
    int armorClass = 10,
    int speed = 30,
    int level = 1,
    this.passivePerception = 10,
    int exhaustionLevel = 0,
    int deathSaveSuccesses = 0,
    int deathSaveFailures = 0,
    this.conditions = const [],
    this.spellSlots = const {},
    this.featSlugs = const [],
    this.equippedItemSlugs = const [],
    this.rulesEdition = 'v2024',
    this.timestamp = 0,
    this.unparsedPayload = const {},
  })  : currentHp = currentHp.clamp(0, 999),
        maxHp = maxHp.clamp(1, 999),
        tempHp = tempHp.clamp(0, 999),
        armorClass = armorClass.clamp(1, 50),
        speed = speed.clamp(0, 300),
        level = level.clamp(1, 20),
        exhaustionLevel = exhaustionLevel.clamp(0, 6),
        deathSaveSuccesses = deathSaveSuccesses.clamp(0, 3),
        deathSaveFailures = deathSaveFailures.clamp(0, 3);

  /// Factory creating an instance from a minified or legacy JSON map with strict clamping.
  factory CharacterTelemetryDto.fromMap(Map<String, dynamic> map) {
    final knownMinifiedKeys = {
      'id', 'n', 'sp', 'bg', 'cl', 'hp', 'mhp', 'thp', 'ac', 'spd',
      'lvl', 'pp', 'exh', 'dss', 'dsf', 'cnd', 'ss', 'ft', 'eq', 're', 'ts'
    };

    // If map appears to be a legacy full Character JSON rather than minified telemetry DTO
    if (map.containsKey('progression') || map.containsKey('baseScores') || map.containsKey('resources')) {
      return CharacterTelemetryDto.fromLegacyCharacterMap(map);
    }

    final id = (map['id'] ?? '').toString();
    final name = (map['n'] ?? map['name'] ?? 'Unknown Adventurer').toString();
    final speciesSlug = (map['sp'] ?? map['speciesSlug'] ?? '').toString();
    final backgroundSlug = map['bg'] != null ? map['bg'].toString() : (map['backgroundSlug']?.toString());

    final rawClasses = map['cl'] ?? map['classPointers'];
    final List<ClassLevelPointerDto> classPointers = [];
    if (rawClasses is List) {
      for (final item in rawClasses) {
        if (item is Map) {
          classPointers.add(ClassLevelPointerDto.fromMap(Map<String, dynamic>.from(item)));
        }
      }
    }

    final currentHp = _asInt(map['hp'] ?? map['currentHp'], fallback: 10).clamp(0, 999);
    final maxHp = _asInt(map['mhp'] ?? map['maxHp'], fallback: 10).clamp(1, 999);
    final tempHp = _asInt(map['thp'] ?? map['tempHp'], fallback: 0).clamp(0, 999);
    final armorClass = _asInt(map['ac'] ?? map['armorClass'], fallback: 10).clamp(1, 50);
    final speed = _asInt(map['spd'] ?? map['speed'], fallback: 30).clamp(0, 300);
    final level = _asInt(map['lvl'] ?? map['level'], fallback: 1).clamp(1, 20);
    final passivePerception = _asInt(map['pp'] ?? map['passivePerception'], fallback: 10).clamp(1, 35);
    final exhaustionLevel = _asInt(map['exh'] ?? map['exhaustionLevel'], fallback: 0).clamp(0, 6);
    final deathSaveSuccesses = _asInt(map['dss'] ?? map['deathSaveSuccesses'], fallback: 0).clamp(0, 3);
    final deathSaveFailures = _asInt(map['dsf'] ?? map['deathSaveFailures'], fallback: 0).clamp(0, 3);

    final rawConditions = map['cnd'] ?? map['conditions'];
    final List<String> conditions = [];
    if (rawConditions is List) {
      for (final c in rawConditions) {
        if (c != null && c.toString().trim().isNotEmpty) {
          conditions.add(c.toString().trim());
        }
      }
    }

    final rawSpellSlots = map['ss'] ?? map['spellSlots'];
    final Map<String, int> spellSlots = {};
    if (rawSpellSlots is Map) {
      rawSpellSlots.forEach((k, v) {
        spellSlots[k.toString()] = _asInt(v, fallback: 0);
      });
    }

    final rawFeats = map['ft'] ?? map['featSlugs'];
    final List<String> featSlugs = [];
    if (rawFeats is List) {
      for (final f in rawFeats) {
        if (f != null && f.toString().trim().isNotEmpty) {
          featSlugs.add(f.toString().trim());
        }
      }
    }

    final rawEquipped = map['eq'] ?? map['equippedItemSlugs'];
    final List<String> equippedItemSlugs = [];
    if (rawEquipped is List) {
      for (final eq in rawEquipped) {
        if (eq != null && eq.toString().trim().isNotEmpty) {
          equippedItemSlugs.add(eq.toString().trim());
        }
      }
    }

    final rulesEdition = (map['re'] ?? map['rulesEdition'] ?? 'v2024').toString();
    final timestamp = _asInt(map['ts'] ?? map['timestamp'], fallback: DateTime.now().millisecondsSinceEpoch);

    final unparsed = <String, dynamic>{};
    map.forEach((key, value) {
      if (!knownMinifiedKeys.contains(key)) {
        unparsed[key] = value;
      }
    });

    return CharacterTelemetryDto(
      id: id,
      name: name,
      speciesSlug: speciesSlug,
      backgroundSlug: backgroundSlug,
      classPointers: classPointers,
      currentHp: currentHp,
      maxHp: maxHp,
      tempHp: tempHp,
      armorClass: armorClass,
      speed: speed,
      level: level,
      passivePerception: passivePerception,
      exhaustionLevel: exhaustionLevel,
      deathSaveSuccesses: deathSaveSuccesses,
      deathSaveFailures: deathSaveFailures,
      conditions: conditions,
      spellSlots: spellSlots,
      featSlugs: featSlugs,
      equippedItemSlugs: equippedItemSlugs,
      rulesEdition: rulesEdition,
      timestamp: timestamp,
      unparsedPayload: unparsed,
    );
  }

  /// Backward-compatibility extractor from full legacy Character map.
  factory CharacterTelemetryDto.fromLegacyCharacterMap(Map<String, dynamic> map) {
    final idMap = map['id'];
    final id = (idMap is Map ? idMap['slug'] : map['id'])?.toString() ?? '';
    final name = map['name']?.toString() ?? 'Adventurer';

    final speciesRef = map['speciesRef'] ?? map['species'];
    final speciesSlug = (speciesRef is Map ? speciesRef['slug'] : (speciesRef is String ? speciesRef : null))?.toString() ?? '';

    final bgRef = map['backgroundRef'] ?? map['background'];
    final backgroundSlug = (bgRef is Map ? bgRef['slug'] : (bgRef is String ? bgRef : null))?.toString();

    final List<ClassLevelPointerDto> classPointers = [];
    int totalLevel = 0;
    final progression = map['progression'];
    final rawClasses = (progression is Map ? progression['classes'] : null) ?? map['classes'] ?? map['classPointers'];
    if (rawClasses is List) {
      for (final item in rawClasses) {
        if (item is Map) {
          final cRef = item['classRef'] ?? item['class'];
          final scRef = item['subclassRef'] ?? item['subclass'];
          final cSlug = (cRef is Map ? cRef['slug'] : (cRef is String ? cRef : ''))?.toString() ?? '';
          final scSlug = (scRef is Map ? scRef['slug'] : (scRef is String ? scRef : null))?.toString();
          final lvl = _asInt(item['level'] ?? item['l'], fallback: 1).clamp(1, 20);
          totalLevel += lvl;
          classPointers.add(ClassLevelPointerDto(
            classSlug: cSlug,
            subclassSlug: scSlug,
            level: lvl,
          ));
        }
      }
    }
    if (totalLevel == 0) totalLevel = 1;

    final resources = map['resources'] is Map ? map['resources'] as Map : const {};
    final currentHp = _asInt(resources['currentHp'], fallback: 10).clamp(0, 999);
    final maxHp = _asInt(resources['maxHp'], fallback: 10).clamp(1, 999);
    final tempHp = _asInt(resources['tempHp'], fallback: 0).clamp(0, 999);
    final armorClass = _asInt(resources['armorClassOverride'], fallback: 10).clamp(1, 50);
    final exhaustionLevel = _asInt(resources['exhaustionLevel'], fallback: 0).clamp(0, 6);

    final deathSaves = resources['deathSaves'] is Map ? resources['deathSaves'] as Map : const {};
    final deathSaveSuccesses = _asInt(deathSaves['successes'], fallback: 0).clamp(0, 3);
    final deathSaveFailures = _asInt(deathSaves['failures'], fallback: 0).clamp(0, 3);

    final speed = _asInt(map['baseSpeedFeet'], fallback: 30).clamp(0, 300);

    final conditions = <String>[];
    if (map['conditions'] is List) {
      for (final c in (map['conditions'] as List)) {
        if (c is Map && c['name'] != null) {
          conditions.add(c['name'].toString());
        } else if (c is String) {
          conditions.add(c);
        }
      }
    }

    final featSlugs = <String>[];
    if (map['feats'] is List) {
      for (final f in (map['feats'] as List)) {
        if (f is Map && f['slug'] != null) {
          featSlugs.add(f['slug'].toString());
        } else if (f is String) {
          featSlugs.add(f);
        }
      }
    }

    final equipped = <String>[];
    if (map['inventory'] is List) {
      for (final item in (map['inventory'] as List)) {
        if (item is Map && item['isEquipped'] == true) {
          final itemRef = item['itemRef'];
          if (itemRef is Map && itemRef['slug'] != null) {
            equipped.add(itemRef['slug'].toString());
          } else if (item['slug'] != null) {
            equipped.add(item['slug'].toString());
          }
        }
      }
    }

    return CharacterTelemetryDto(
      id: id,
      name: name,
      speciesSlug: speciesSlug,
      backgroundSlug: backgroundSlug,
      classPointers: classPointers,
      currentHp: currentHp,
      maxHp: maxHp,
      tempHp: tempHp,
      armorClass: armorClass,
      speed: speed,
      level: totalLevel.clamp(1, 20),
      passivePerception: 10,
      exhaustionLevel: exhaustionLevel,
      deathSaveSuccesses: deathSaveSuccesses,
      deathSaveFailures: deathSaveFailures,
      conditions: conditions,
      featSlugs: featSlugs,
      equippedItemSlugs: equipped,
      rulesEdition: map['rulesEdition']?.toString() ?? 'v2024',
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'id': id,
      'n': name,
      'name': name,
      'sp': speciesSlug,
      'cl': classPointers.map((c) => c.toMap()).toList(),
      'hp': currentHp.clamp(0, 999),
      'mhp': maxHp.clamp(1, 999),
      'thp': tempHp.clamp(0, 999),
      'ac': armorClass.clamp(1, 50),
      'spd': speed.clamp(0, 300),
      'lvl': level.clamp(1, 20),
      'pp': passivePerception.clamp(1, 35),
      'exh': exhaustionLevel.clamp(0, 6),
      'dss': deathSaveSuccesses.clamp(0, 3),
      'dsf': deathSaveFailures.clamp(0, 3),
      're': rulesEdition,
      'ts': timestamp,
    };

    if (backgroundSlug != null && backgroundSlug!.isNotEmpty) {
      map['bg'] = backgroundSlug;
    }
    if (conditions.isNotEmpty) {
      map['cnd'] = conditions;
    }
    if (spellSlots.isNotEmpty) {
      map['ss'] = spellSlots;
    }
    if (featSlugs.isNotEmpty) {
      map['ft'] = featSlugs;
    }
    if (equippedItemSlugs.isNotEmpty) {
      map['eq'] = equippedItemSlugs;
    }

    map.addAll(unparsedPayload);
    return map;
  }

  String toJson() => jsonEncode(toMap());

  factory CharacterTelemetryDto.fromJson(String source) =>
      CharacterTelemetryDto.fromMap(jsonDecode(source) as Map<String, dynamic>);

  CharacterTelemetryDto copyWith({
    String? id,
    String? name,
    String? speciesSlug,
    String? backgroundSlug,
    List<ClassLevelPointerDto>? classPointers,
    int? currentHp,
    int? maxHp,
    int? tempHp,
    int? armorClass,
    int? speed,
    int? level,
    int? passivePerception,
    int? exhaustionLevel,
    int? deathSaveSuccesses,
    int? deathSaveFailures,
    List<String>? conditions,
    Map<String, int>? spellSlots,
    List<String>? featSlugs,
    List<String>? equippedItemSlugs,
    String? rulesEdition,
    int? timestamp,
    Map<String, dynamic>? unparsedPayload,
  }) {
    return CharacterTelemetryDto(
      id: id ?? this.id,
      name: name ?? this.name,
      speciesSlug: speciesSlug ?? this.speciesSlug,
      backgroundSlug: backgroundSlug ?? this.backgroundSlug,
      classPointers: classPointers ?? this.classPointers,
      currentHp: currentHp ?? this.currentHp,
      maxHp: maxHp ?? this.maxHp,
      tempHp: tempHp ?? this.tempHp,
      armorClass: armorClass ?? this.armorClass,
      speed: speed ?? this.speed,
      level: level ?? this.level,
      passivePerception: passivePerception ?? this.passivePerception,
      exhaustionLevel: exhaustionLevel ?? this.exhaustionLevel,
      deathSaveSuccesses: deathSaveSuccesses ?? this.deathSaveSuccesses,
      deathSaveFailures: deathSaveFailures ?? this.deathSaveFailures,
      conditions: conditions ?? this.conditions,
      spellSlots: spellSlots ?? this.spellSlots,
      featSlugs: featSlugs ?? this.featSlugs,
      equippedItemSlugs: equippedItemSlugs ?? this.equippedItemSlugs,
      rulesEdition: rulesEdition ?? this.rulesEdition,
      timestamp: timestamp ?? this.timestamp,
      unparsedPayload: unparsedPayload ?? this.unparsedPayload,
    );
  }

  static int _asInt(dynamic val, {int fallback = 0}) {
    if (val is num) return val.toInt();
    if (val is String) return int.tryParse(val) ?? fallback;
    return fallback;
  }
}
